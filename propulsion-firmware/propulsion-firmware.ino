#include <SensorManager.h>
#include <CommsOut.h>

// Create global CommsOut and SensorManager instances
CommsOut comms;
SensorManager manager(&comms);

void setup() {
    Serial.begin(115200);
    manager.setup();
}

void loop() {
    manager.pollSensors();
    delay(1000); // Basic polling interval
}
