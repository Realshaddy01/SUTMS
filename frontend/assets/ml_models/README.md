# Nepali License Plate OCR Model

This directory contains the trained model for Nepali license plate character recognition.

## Model Information

- Source: Kaggle notebook by nzlkharel/nepali-text-predict-98-cnn
- Accuracy: 97.4%
- Framework: TensorFlow/Keras
- Input Shape: 32x32x3 (RGB images)
- Output: 34 classes (Nepali characters)

## Usage

1. Download the model file using Kaggle CLI:
   ```bash
   kaggle kernels output nzlkharel/nepali-text-predict-98-cnn -p /path/to/download
   ```

2. Place the model files in this directory:
   - `model.h5` - The main model file

3. The MLModelService class in the app will automatically load and use this model for license plate character recognition.

## Character Mapping

The model recognizes the following Nepali characters:

```
0: 'क', 1: 'ख', 2: 'ग', 3: 'घ', 4: 'ङ', 5: 'च', 6: 'छ', 7: 'ज', 
8: 'झ', 9: 'ञ', 10: 'ट', 11: 'ठ', 12: 'ड', 13: 'ढ', 14: 'ण', 15: 'त', 
16: 'थ', 17: 'द', 18: 'ध', 19: 'न', 20: 'प', 21: 'फ', 22: 'ब', 23: 'भ', 
24: 'म', 25: 'य', 26: 'र', 27: 'ल', 28: 'व', 29: 'श', 30: 'ष', 31: 'स', 
32: 'ह', 33: 'क्ष'
``` 