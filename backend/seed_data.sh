#!/bin/bash

# Activate virtual environment if exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run migrations
python manage.py migrate

# Seed the data
python manage.py seed_data
python manage.py seed_notifications

# Create superuser if not exists
python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@traffic.gov.np', 'admin123')
EOF

echo "Data seeding completed successfully!" 