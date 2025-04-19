#!/bin/bash

# This script helps create the kaggle.json file
echo "Creating your kaggle.json file..."

# Ask for Kaggle username
echo -n "Enter your Kaggle username: "
read KAGGLE_USERNAME

# Ask for Kaggle API key
echo -n "Enter your Kaggle API key: "
read KAGGLE_KEY

# Create the directory if it doesn't exist
mkdir -p ~/.kaggle

# Create the kaggle.json file
echo "{\"username\":\"$KAGGLE_USERNAME\",\"key\":\"$KAGGLE_KEY\"}" > ~/.kaggle/kaggle.json

# Set the correct permissions
chmod 600 ~/.kaggle/kaggle.json

echo "kaggle.json file created successfully at ~/.kaggle/kaggle.json"
echo "You can now run: kaggle kernels output nzlkharel/nepali-text-predict-98-cnn -p frontend/assets/ml_models" 