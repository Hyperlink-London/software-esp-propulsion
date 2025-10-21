/*
This file is used to store all the #defines of all the sensors.
When a #define is NOT commented out the sensor is included in the sensorManager class.

When setting up and ESP, ONLY UNCOMMENT the sensors you WANT to be used by the ESP
*/

// Sensor enable/disable flags
#define USE_DEMO
#define USE_DEMO_TWO

// Pin configuration arrays
#ifdef USE_DEMO
    #define DEMO_PINS {18, 19}
#endif

#ifdef USE_DEMO_TWO
    #define DEMO_TWO_PINS {21, 22, 23}
#endif