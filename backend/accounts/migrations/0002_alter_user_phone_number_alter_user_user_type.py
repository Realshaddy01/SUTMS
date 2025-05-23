# Generated by Django 4.2.9 on 2025-04-11 00:28

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='phone_number',
            field=models.CharField(blank=True, max_length=15, null=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='user_type',
            field=models.CharField(choices=[('vehicle_owner', 'Vehicle Owner'), ('traffic_officer', 'Traffic Officer'), ('admin', 'Administrator')], default='vehicle_owner', max_length=20),
        ),
    ]
