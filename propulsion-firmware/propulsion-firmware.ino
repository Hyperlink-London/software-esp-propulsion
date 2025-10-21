#include <SerialAliases.h>
#include <SensorManager.h>
#include <CommsOut.h>
#include <CommsIn.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"

CommsOut commsOut("esp-propulsion");
CommsIn commsIn;
SensorManager manager(&commsOut);


TaskHandle_t SensorTask;
TaskHandle_t CommTask;

void PollSensors(void *pvParameters) {
    if(!manager.arePinsValidated()) {
        Serial_1.println("ERROR: Pins are not validated! SensorManager will not operate on core 0.");
    }
    while(manager.arePinsValidated()) {
        manager.pollSensors();
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
    
}

void HandleCommunication(void *pvParameters) {
    while (true) {
        commsIn.isStale();
        commsIn.receive();
        commsOut.drainQueue();
        vTaskDelay(pdMS_TO_TICKS(5));
    }
}


void setup() {
    Serial_1.begin(9600);
    Serial_0.begin(115200, SERIAL_8N1, 16, 17); // adjust pins as needed

    manager.setup();
    xTaskCreatePinnedToCore(
        PollSensors,  
        "SensorTask",  
        10000,        
        NULL,        
        1,           
        &SensorTask,  
        0            
    );

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
}
