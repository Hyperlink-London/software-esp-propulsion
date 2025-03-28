#include "config.h"

#include <SensorManager.h>
#include <CommsOut.h>

// Create global CommsOut and SensorManager instances
CommsOut comms("esp-propulsion");
SensorManager manager(&comms);

void setup() {
    Serial.begin(9600);
    manager.setup();
}

void loop() {
    manager.pollSensors();
    delay(1000); // Basic polling interval
}
