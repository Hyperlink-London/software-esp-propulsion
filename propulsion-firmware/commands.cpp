#include "commands.h"
#include <SerialAliases.h>
#include <Arduino.h>

// Command handler implementations
void turn_on_brake() {
    Serial_1.println("Brake turned ON");
    // Add your brake control logic here
}

void turn_off_brake() {
    Serial_1.println("Brake turned OFF");
    // Add your brake control logic here
}

// Add more command implementations as needed

