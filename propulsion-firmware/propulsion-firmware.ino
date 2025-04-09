#include <SensorManager.h>
#include <CommsOut.h>
#include <CommsIn.h>

// Create global instances
CommsOut comms("esp-propulsion");
CommsIn commsIn;
SensorManager manager(&comms);


TaskHandle_t SensorTask;
TaskHandle_t CommTask;

// Sensor polling (Core 0)
void PollSensors(void *pvParameters) {
    while(true) {
        Serial.printf("SensorTask running on Core %d. Free Heap: %d\n", xPortGetCoreID(), esp_get_free_heap_size());
        manager.pollSensors();
        delay(1000);
    }
    
}

// Communication handling (Core 1)
void HandleCommunication(void *pvParameters) {
    while (true) {
        Serial.printf("CommTask running on Core %d. Free Heap: %d\n", xPortGetCoreID(), esp_get_free_heap_size());
        delay(1000);
    }
}


void setup() {
    Serial.begin(9600);
    manager.setup();
    // Assign tasks to cores
    // Assign sensor polling to Core 0
    xTaskCreatePinnedToCore(
        PollSensors,  
        "SensorTask",  
        10000,        
        NULL,        
        1,           
        &SensorTask,  
        0            
    );

    // Assign communication handling to Core 1
    xTaskCreatePinnedToCore(
        HandleCommunication,
        "CommTask",
        10000,
        NULL,
        1,
        &CommTask,
        1
    );



}

void loop() {
    //manager.pollSensors();
    //delay(1000); // Basic polling interval
    //Serial.println("Looping...");
}
