# Generated by Django 5.2 on 2025-04-06 13:12

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='ModelTraining',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('description', models.TextField(blank=True)),
                ('model_type', models.CharField(max_length=50)),
                ('hyperparameters', models.JSONField(default=dict)),
                ('training_images_count', models.IntegerField(default=0)),
                ('validation_images_count', models.IntegerField(default=0)),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('training', 'Training'), ('completed', 'Completed'), ('failed', 'Failed')], default='pending', max_length=20)),
                ('started_at', models.DateTimeField(blank=True, null=True)),
                ('completed_at', models.DateTimeField(blank=True, null=True)),
                ('accuracy', models.FloatField(blank=True, null=True)),
                ('loss', models.FloatField(blank=True, null=True)),
                ('model_file', models.FileField(blank=True, null=True, upload_to='trained_models/')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('initiated_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='initiated_model_trainings', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Model Training',
                'verbose_name_plural': 'Model Trainings',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='ModelTrainingLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('epoch', models.IntegerField(blank=True, null=True)),
                ('step', models.IntegerField(blank=True, null=True)),
                ('train_loss', models.FloatField(blank=True, null=True)),
                ('val_loss', models.FloatField(blank=True, null=True)),
                ('train_accuracy', models.FloatField(blank=True, null=True)),
                ('val_accuracy', models.FloatField(blank=True, null=True)),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('training', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='logs', to='training.modeltraining')),
            ],
            options={
                'verbose_name': 'Training Log',
                'verbose_name_plural': 'Training Logs',
                'ordering': ['training', 'epoch', 'step'],
            },
        ),
        migrations.CreateModel(
            name='TrainingImage',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('image', models.ImageField(upload_to='training_images/')),
                ('license_plate_text', models.CharField(max_length=20)),
                ('bounding_box', models.CharField(blank=True, max_length=100)),
                ('dataset_type', models.CharField(choices=[('training', 'Training'), ('validation', 'Validation'), ('test', 'Test')], default='training', max_length=20)),
                ('is_verified', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('added_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='added_training_images', to=settings.AUTH_USER_MODEL)),
                ('verified_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='verified_training_images', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Training Image',
                'verbose_name_plural': 'Training Images',
                'ordering': ['-created_at'],
            },
        ),
    ]
