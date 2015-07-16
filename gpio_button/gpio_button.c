// WiringPi-Api einbinden
#include <wiringPi.h>
#include <stdio.h>


/*
int main() {

  // Starte die WiringPi-Api (wichtig)
  if (wiringPiSetup() == -1)
    return 1;

  // Schalte GPIO 17 (=WiringPi Pin 0) auf Ausgang
  // Wichtig: Hier wird das WiringPi Layout verwendet (Tabelle oben)
  pinMode(0, OUTPUT);

  // Dauerschleife
  while(1) {
    // LED an
    digitalWrite(0, 1);

    // Warte 100 ms
    delay(100);

    // LED aus
    digitalWrite(0, 0);

    // Warte 100 ms
    delay(100);
  }
}
*/


// Wird aufgefrufen wenn der Button gedrückt wurd 
PI_THREAD (waitForIt) {


}

void setup (void)
{

// Use the gpio program to initialise the hardware
//  (This is the crude, but effective)

  system ("gpio edge 17 falling") ;

// Setup wiringPi

  wiringPiSetupSys () ;

// Fire off our interrupt handler

  piThreadCreate (waitForIt) ;

}



int main(int argc, char **argv) {
 // int c
 // c = getopt (argc, argv, "bs")
  
  printf("hallo erste arument %s\n", argv[1]);
  system ("echo welt argv[0]");

}

