"""
Utility functions for route recommendation system.
"""
import os
import json
import logging
import requests
import numpy as np
from datetime import datetime, timedelta
from django.conf import settings
from django.utils import timezone
from sklearn.ensemble import RandomForestRegressor
from .models import TrafficData, PeakTrafficTime, RouteRecommendation

# Google Maps API Key from environment
GOOGLE_MAPS_API_KEY = os.environ.get('GOOGLE_MAPS_API_KEY')

# Setup logging
logger = logging.getLogger('sutms.routing')

# Base URL for Google Maps Directions API
DIRECTIONS_API_URL = "https://maps.googleapis.com/maps/api/directions/json"

# Base URL for Google Maps Distance Matrix API
DISTANCE_MATRIX_API_URL = "https://maps.googleapis.com/maps/api/distancematrix/json"


def get_directions(origin_lat, origin_lng, destination_lat, destination_lng, alternatives=True, avoid=None, mode="driving"):
    """
    Get directions from Google Maps Directions API.
    
    Args:
        origin_lat (float): Origin latitude
        origin_lng (float): Origin longitude
        destination_lat (float): Destination latitude
        destination_lng (float): Destination longitude
        alternatives (bool): Whether to return alternative routes
        avoid (str): Features to avoid (tolls, highways, ferries)
        mode (str): Travel mode (driving, walking, bicycling, transit)
        
    Returns:
        dict: Direction data from Google Maps
    """
    try:
        params = {
            "origin": f"{origin_lat},{origin_lng}",
            "destination": f"{destination_lat},{destination_lng}",
            "alternatives": str(alternatives).lower(),
            "mode": mode,
            "key": GOOGLE_MAPS_API_KEY,
            "departure_time": "now",
            "traffic_model": "best_guess",
        }
        
        if avoid:
            params["avoid"] = avoid
            
        response = requests.get(DIRECTIONS_API_URL, params=params)
        response.raise_for_status()
        
        return response.json()
    except Exception as e:
        logger.error(f"Error getting directions: {str(e)}")
        return None


def analyze_traffic_on_route(directions_data):
    """
    Analyze traffic conditions on a route based on Google Maps data.
    
    Args:
        directions_data (dict): Direction data from Google Maps
        
    Returns:
        dict: Traffic analysis with scores for each route
    """
    if not directions_data or "routes" not in directions_data:
        return None
    
    analysis = {
        "routes": []
    }
    
    for i, route in enumerate(directions_data["routes"]):
        duration_in_traffic = 0
        normal_duration = 0
        traffic_segments = []
        
        if "legs" in route:
            for leg in route["legs"]:
                if "duration_in_traffic" in leg:
                    duration_in_traffic += leg["duration_in_traffic"]["value"]
                if "duration" in leg:
                    normal_duration += leg["duration"]["value"]
                
                if "steps" in leg:
                    for step in leg["steps"]:
                        if "duration_in_traffic" in step and "duration" in step:
                            traffic_ratio = step["duration_in_traffic"]["value"] / step["duration"]["value"]
                            traffic_segments.append({
                                "start_location": step["start_location"],
                                "end_location": step["end_location"],
                                "traffic_ratio": traffic_ratio,
                                "distance": step["distance"]["value"],
                                "duration": step["duration"]["value"],
                                "duration_in_traffic": step.get("duration_in_traffic", {}).get("value", step["duration"]["value"])
                            })
        
        # Calculate traffic level (0-100)
        traffic_level = 0
        if normal_duration > 0:
            traffic_level = min(100, max(0, int((duration_in_traffic - normal_duration) / normal_duration * 100)))
        
        # Find congested segments (traffic_ratio > 1.5)
        congested_segments = [seg for seg in traffic_segments if seg["traffic_ratio"] > 1.5]
        
        # Calculate percentage of route that is congested
        total_distance = sum(seg["distance"] for seg in traffic_segments) if traffic_segments else 0
        congested_distance = sum(seg["distance"] for seg in congested_segments) if congested_segments else 0
        congestion_percentage = (congested_distance / total_distance * 100) if total_distance > 0 else 0
        
        route_analysis = {
            "route_index": i,
            "summary": route.get("summary", ""),
            "normal_duration_seconds": normal_duration,
            "duration_in_traffic_seconds": duration_in_traffic,
            "traffic_level": traffic_level,
            "congested_segments": congested_segments,
            "congestion_percentage": congestion_percentage,
            "is_recommended": False  # Will be set later
        }
        
        analysis["routes"].append(route_analysis)
    
    # Determine the recommended route (lowest traffic_level)
    if analysis["routes"]:
        recommended_route = min(analysis["routes"], key=lambda x: x["traffic_level"])
        recommended_route["is_recommended"] = True
    
    return analysis


def is_peak_traffic_time(latitude, longitude):
    """
    Check if current time is a peak traffic time for the given location.
    
    Args:
        latitude (float): Latitude of the location
        longitude (float): Longitude of the location
        
    Returns:
        bool: True if current time is peak traffic time, False otherwise
    """
    now = timezone.now()
    day_of_week = now.weekday()  # 0 = Monday, 6 = Sunday
    hour_of_day = now.hour
    
    # Get all peak traffic times for the current day and hour
    peak_times = PeakTrafficTime.objects.filter(
        day_of_week=day_of_week,
        start_hour__lte=hour_of_day,
        end_hour__gt=hour_of_day
    )
    
    # Check if the location is within any peak traffic area
    for peak in peak_times:
        # Calculate distance using Haversine formula
        R = 6371000  # Earth radius in meters
        dLat = np.radians(latitude - peak.center_lat)
        dLon = np.radians(longitude - peak.center_lng)
        a = (np.sin(dLat/2) * np.sin(dLat/2) + 
             np.cos(np.radians(peak.center_lat)) * np.cos(np.radians(latitude)) * 
             np.sin(dLon/2) * np.sin(dLon/2))
        c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1-a))
        distance = R * c
        
        if distance <= peak.radius_meters:
            return True
            
    return False


def predict_traffic_level(origin_lat, origin_lng, destination_lat, destination_lng, timestamp=None):
    """
    Predict traffic level using the trained model for a given route and time.
    
    Args:
        origin_lat (float): Origin latitude
        origin_lng (float): Origin longitude
        destination_lat (float): Destination latitude
        destination_lng (float): Destination longitude
        timestamp (datetime): Time for prediction (default: current time)
        
    Returns:
        int: Predicted traffic level (0-100)
    """
    if timestamp is None:
        timestamp = timezone.now()
    
    # Prepare features
    day_of_week = timestamp.weekday()
    hour_of_day = timestamp.hour
    is_holiday = False  # A more complex logic would be needed to determine holidays
    
    # For a simple model, we'll use recent similar traffic data
    # Get traffic data from similar times in the past week
    similar_data = TrafficData.objects.filter(
        day_of_week=day_of_week,
        hour_of_day__range=(hour_of_day-1, hour_of_day+1)
    ).order_by('-timestamp')[:50]  # Get the 50 most recent samples
    
    if not similar_data:
        # If no similar data, check if it's peak traffic time
        if is_peak_traffic_time(origin_lat, origin_lng) or is_peak_traffic_time(destination_lat, destination_lng):
            return 75  # Default high traffic level during peak hours
        return 30  # Default moderate traffic level
    
    # Use the average of similar traffic levels
    avg_traffic_level = sum(data.traffic_level for data in similar_data) / len(similar_data)
    return int(avg_traffic_level)


def train_traffic_model():
    """
    Train a machine learning model to predict traffic levels.
    This function should be run periodically to update the model.
    
    Returns:
        model: Trained RandomForestRegressor model
    """
    # Get all traffic data
    traffic_data = TrafficData.objects.all()
    
    if not traffic_data or len(traffic_data) < 100:
        logger.warning("Not enough traffic data to train the model")
        return None
    
    # Prepare features and target
    X = []
    y = []
    
    for data in traffic_data:
        # Features: day of week, hour of day, origin coordinates, destination coordinates
        features = [
            data.day_of_week,
            data.hour_of_day,
            data.is_holiday,
            data.is_rush_hour,
            data.origin_lat,
            data.origin_lng,
            data.destination_lat,
            data.destination_lng
        ]
        
        X.append(features)
        y.append(data.traffic_level)
    
    # Train a RandomForest model
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X, y)
    
    # Save model metadata
    with open(os.path.join(settings.MEDIA_ROOT, 'traffic_model_info.json'), 'w') as f:
        json.dump({
            "trained_at": timezone.now().isoformat(),
            "data_points": len(X),
            "feature_importance": model.feature_importances_.tolist(),
            "features": [
                "day_of_week",
                "hour_of_day",
                "is_holiday",
                "is_rush_hour",
                "origin_lat",
                "origin_lng",
                "destination_lat",
                "destination_lng"
            ]
        }, f)
    
    return model


def get_alternative_routes(origin_lat, origin_lng, destination_lat, destination_lng, user=None):
    """
    Get and analyze alternative routes, including traffic predictions.
    
    Args:
        origin_lat (float): Origin latitude
        origin_lng (float): Origin longitude
        destination_lat (float): Destination latitude
        destination_lng (float): Destination longitude
        user (User): User object
        
    Returns:
        dict: Analyzed routes with traffic predictions
    """
    # Get directions with alternatives
    directions_data = get_directions(
        origin_lat, origin_lng, destination_lat, destination_lng, 
        alternatives=True
    )
    
    if not directions_data or "routes" not in directions_data:
        logger.error("Failed to get directions from Google Maps API")
        return None
    
    # Analyze traffic on routes
    traffic_analysis = analyze_traffic_on_route(directions_data)
    
    if not traffic_analysis:
        logger.error("Failed to analyze traffic on routes")
        return None
    
    # Add prediction and save recommendations
    results = {
        "origin": {
            "lat": origin_lat,
            "lng": origin_lng
        },
        "destination": {
            "lat": destination_lat,
            "lng": destination_lng
        },
        "timestamp": timezone.now().isoformat(),
        "routes": []
    }
    
    for i, route_analysis in enumerate(traffic_analysis["routes"]):
        route = directions_data["routes"][i]
        
        # Get predicted traffic level
        predicted_traffic = predict_traffic_level(
            origin_lat, origin_lng, destination_lat, destination_lng
        )
        
        # Determine route type
        if route_analysis["is_recommended"]:
            route_type = RouteRecommendation.RouteType.FASTEST
        elif route_analysis["traffic_level"] == min(r["traffic_level"] for r in traffic_analysis["routes"]):
            route_type = RouteRecommendation.RouteType.LEAST_TRAFFIC
        else:
            route_type = RouteRecommendation.RouteType.ALTERNATE
        
        # Extract polyline for the route
        polyline = route.get("overview_polyline", {}).get("points", "")
        
        # Get distance and duration
        distance_meters = 0
        duration_seconds = 0
        if "legs" in route:
            for leg in route["legs"]:
                distance_meters += leg.get("distance", {}).get("value", 0)
                duration_seconds += leg.get("duration_in_traffic", leg.get("duration", {})).get("value", 0)
        
        # Create route result
        route_result = {
            "route_index": i,
            "route_type": route_type,
            "summary": route.get("summary", ""),
            "polyline": polyline,
            "distance_meters": distance_meters,
            "duration_seconds": duration_seconds,
            "traffic_level": route_analysis["traffic_level"],
            "predicted_traffic_level": predicted_traffic,
            "is_recommended": route_analysis["is_recommended"],
            "congestion_percentage": route_analysis["congestion_percentage"]
        }
        
        results["routes"].append(route_result)
        
        # Save recommendation if user is provided
        if user and user.is_authenticated:
            RouteRecommendation.objects.create(
                user=user,
                origin_lat=origin_lat,
                origin_lng=origin_lng,
                destination_lat=destination_lat,
                destination_lng=destination_lng,
                route_type=route_type,
                travel_time_seconds=duration_seconds,
                distance_meters=distance_meters,
                route_data=json.dumps(route),
                traffic_level=route_analysis["traffic_level"]
            )
    
    # Sort routes by recommendation status and then by duration
    results["routes"].sort(key=lambda x: (not x["is_recommended"], x["duration_seconds"]))
    
    return results


def update_traffic_data_from_directions(directions_data, save=True):
    """
    Update traffic data database from Google Maps directions data.
    
    Args:
        directions_data (dict): Direction data from Google Maps API
        save (bool): Whether to save the data to the database
        
    Returns:
        list: Created TrafficData objects
    """
    if not directions_data or "routes" not in directions_data:
        return []
    
    now = timezone.now()
    created_data = []
    
    for route in directions_data["routes"]:
        if "legs" in route:
            for leg in route["legs"]:
                # Extract origin and destination
                origin = leg.get("start_location", {})
                destination = leg.get("end_location", {})
                
                if not origin or not destination:
                    continue
                
                # Get traffic information
                distance_meters = leg.get("distance", {}).get("value", 0)
                normal_duration = leg.get("duration", {}).get("value", 0)
                duration_in_traffic = leg.get("duration_in_traffic", {}).get("value", normal_duration)
                
                # Calculate traffic level (0-100)
                traffic_level = 0
                if normal_duration > 0:
                    traffic_level = min(100, max(0, int((duration_in_traffic - normal_duration) / normal_duration * 100)))
                
                # Determine if it's rush hour
                hour_of_day = now.hour
                is_rush_hour = (
                    (hour_of_day >= 7 and hour_of_day <= 10) or  # Morning rush hour
                    (hour_of_day >= 16 and hour_of_day <= 19)     # Evening rush hour
                )
                
                # Create TrafficData object
                traffic_data = TrafficData(
                    origin_lat=origin.get("lat"),
                    origin_lng=origin.get("lng"),
                    destination_lat=destination.get("lat"),
                    destination_lng=destination.get("lng"),
                    traffic_level=traffic_level,
                    travel_time_seconds=duration_in_traffic,
                    distance_meters=distance_meters,
                    timestamp=now,
                    day_of_week=now.weekday(),
                    hour_of_day=hour_of_day,
                    is_rush_hour=is_rush_hour
                )
                
                if save:
                    traffic_data.save()
                
                created_data.append(traffic_data)
    
    return created_data