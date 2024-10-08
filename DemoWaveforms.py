import numpy as np
import ardi

def outputSine():
    print("Sine wave function called.")

def outputSquare():
    print("Square wave function called.")

def outputChirp():
    print("Chirp wave function called.")

def outputHeartbeat():
    print("Heartbeat wave function called.")

def main():
    psu = ardi.autoconnect() # connect to Artimus HVPS
    ch1 = psu.channels['ch1'] # add single output channel

    # Collect user input
    while True:
        print("Select output signal")
        print("1: Sine")
        print("2: Square")
        print("3: Chirp")
        print("4: Heartbeat")
        print("5: Exit")
        
        user_input = input("Enter your choice (1-5): ")

        if user_input == '1':
            outputSine()
        elif user_input == '2':
            outputSquare()
        elif user_input == '3':
            outputChirp()
        elif user_input == '4':
            outputHeartbeat()
        elif user_input == '5':
            print("Exiting...")
            break
        else:
            print("Invalid input. Please enter a number between 1 and 5.")

if __name__ == "__main__":
    main()