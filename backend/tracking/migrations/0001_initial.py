# Generated by Django 5.2 on 2025-04-06 13:12

import django.db.models.deletion
import django.utils.timezone
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Incident',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('incident_type', models.CharField(choices=[('accident', 'Accident'), ('breakdown', 'Vehicle Breakdown'), ('obstruction', 'Road Obstruction'), ('weather', 'Weather Condition'), ('construction', 'Construction'), ('signal_issue', 'Traffic Signal Issue'), ('congestion', 'Traffic Congestion'), ('other', 'Other')], default='other', max_length=20, verbose_name='incident type')),
                ('description', models.TextField(blank=True, verbose_name='description')),
                ('latitude', models.FloatField(verbose_name='latitude')),
                ('longitude', models.FloatField(verbose_name='longitude')),
                ('reported_at', models.DateTimeField(default=django.utils.timezone.now, verbose_name='reported at')),
                ('status', models.CharField(choices=[('reported', 'Reported'), ('responding', 'Responding'), ('in_progress', 'In Progress'), ('resolved', 'Resolved'), ('cancelled', 'Cancelled')], default='reported', max_length=20, verbose_name='status')),
                ('severity', models.CharField(choices=[('low', 'Low'), ('medium', 'Medium'), ('high', 'High'), ('critical', 'Critical')], default='medium', max_length=20, verbose_name='severity')),
                ('updated_at', models.DateTimeField(blank=True, null=True, verbose_name='updated at')),
                ('resolved_at', models.DateTimeField(blank=True, null=True, verbose_name='resolved at')),
                ('resolution', models.TextField(blank=True, verbose_name='resolution')),
                ('officers_assigned', models.ManyToManyField(blank=True, related_name='assigned_incidents', to=settings.AUTH_USER_MODEL)),
                ('reported_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='reported_incidents', to=settings.AUTH_USER_MODEL)),
                ('updated_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='updated_incidents', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'incident',
                'verbose_name_plural': 'incidents',
                'ordering': ['-reported_at'],
            },
        ),
        migrations.CreateModel(
            name='OfficerLocation',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('latitude', models.FloatField(verbose_name='latitude')),
                ('longitude', models.FloatField(verbose_name='longitude')),
                ('accuracy', models.FloatField(default=0, verbose_name='accuracy in meters')),
                ('speed', models.FloatField(default=0, verbose_name='speed in km/h')),
                ('heading', models.FloatField(default=0, verbose_name='heading in degrees')),
                ('battery_level', models.FloatField(default=0, verbose_name='battery level percentage')),
                ('last_updated', models.DateTimeField(default=django.utils.timezone.now, verbose_name='last updated')),
                ('officer', models.ForeignKey(help_text='The officer being tracked', on_delete=django.db.models.deletion.CASCADE, related_name='locations', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'officer location',
                'verbose_name_plural': 'officer locations',
                'ordering': ['-last_updated'],
            },
        ),
        migrations.CreateModel(
            name='TrafficSignal',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('name', models.CharField(max_length=100, verbose_name='name')),
                ('code', models.CharField(max_length=50, unique=True, verbose_name='signal code')),
                ('latitude', models.FloatField(verbose_name='latitude')),
                ('longitude', models.FloatField(verbose_name='longitude')),
                ('status', models.CharField(choices=[('operational', 'Operational'), ('maintenance', 'Under Maintenance'), ('offline', 'Offline'), ('warning', 'Warning Mode'), ('malfunction', 'Malfunction')], default='operational', max_length=20, verbose_name='status')),
                ('installed_date', models.DateField(blank=True, null=True, verbose_name='installation date')),
                ('last_maintained', models.DateField(blank=True, null=True, verbose_name='last maintenance')),
                ('last_updated', models.DateTimeField(auto_now=True, verbose_name='last updated')),
                ('notes', models.TextField(blank=True, verbose_name='notes')),
                ('updated_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='updated_signals', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'traffic signal',
                'verbose_name_plural': 'traffic signals',
                'ordering': ['name'],
            },
        ),
    ]
