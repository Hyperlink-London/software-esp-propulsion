#include <SensorManager.h>
#include <CommsOut.h>
#include <CommsIn.h>

// Create global instances
CommsOut comms("esp-propulsion");
CommsIn commsIn;
SensorManager manager(&comms);

void setup() {
    Serial.begin(9600);
    manager.setup();
}

void loop() {
    manager.pollSensors();
    commsIn.receive();  // Check for incoming messages
    delay(1000);  // Basic polling interval
}
