import ardi
import numpy as np
from numpy import pi
import matplotlib.pyplot as plt
from scipy.signal import chirp

def outputHeartbeat(ch1, sample_rate, max_voltage, voltage_lub, dc_offset):
    print("Heartbeat wave function called.")

    f0 = 1 # [Hz]
    fraction_lub = 0.25 # fraction of cycle for lub part
    fraction_down = 0.25 # fraction of cycle in between dub and lub
    fraction_dub = 0.25 # fraction of cycle for dub part

    samples_per_cycle = int(sample_rate/f0)
    lub_samples = int(samples_per_cycle*fraction_lub)
    down_samples = int(samples_per_cycle*fraction_down)
    dub_samples = int(samples_per_cycle*fraction_dub)

    xs = np.sin(np.linspace(0, 2*pi, lub_samples) - pi/2)
    lub = (voltage_lub-dc_offset)*((1/2)*xs + (1/2)) + dc_offset
    xs = np.sin(np.linspace(0, 2*pi, down_samples) + pi/2)
    down = dc_offset*((1/2)*xs + (1/2))
    xs = np.sin(np.linspace(0, 2*pi, dub_samples) - pi/2)
    dub = (max_voltage - dc_offset)*((1/2)*xs + (1/2)) + dc_offset
    output_waveform = np.concatenate((lub, down, dub, down))

    #plt.plot(output_waveform)
    #plt.show()
    ch1.waveform(output_waveform, sample_rate)

def outputSuperimposed(ch1, sample_rate, f0, f1, max_voltage_f0, max_voltage_f1, dc_offset):
    print("Superimposed sine wave function called.")

    # Create f0 sine (1 period)
    samples_per_cycle = int(sample_rate/f0)
    xs = np.linspace(0, 2*np.pi, samples_per_cycle)-np.pi/2
    sine_f0 = max_voltage_f0*((np.sin(xs)+1)/2)

    # Create f1 sine (1 period of f0)
    samples_per_cycle = int(sample_rate/f1)
    num_cycles = int(f1/f0)
    xs = np.linspace(0, 2*np.pi*num_cycles, samples_per_cycle*num_cycles)-np.pi/2
    sine_f1 = max_voltage_f1*((np.sin(xs)+1)/2)
    output_waveform = sine_f0 + sine_f1 + dc_offset

    #plt.plot(output_waveform)
    #plt.show()
    ch1.waveform(output_waveform, sample_rate)

def outputChirp(ch1, sample_rate, f0, f1, T, max_voltage, dc_offset):
    xs = np.linspace(0, T, int(T*sample_rate))
    output_waveform = -(1/2)*chirp(xs, f0=f0, t1=T, f1=f1, method='linear')+(1/2)
    output_waveform = np.concatenate((output_waveform, output_waveform[::-1]))
    output_waveform = (max_voltage-dc_offset)*output_waveform+dc_offset

    # Add voltage ramp to beginning and end of signal
    ramp = np.linspace(0, dc_offset, 100)
    output_waveform = np.concatenate((ramp, output_waveform, ramp[::-1]))

    #plt.plot(output_waveform)
    #plt.show()
    ch1.waveform(output_waveform, sample_rate)

def main():
    psu = ardi.autoconnect() # connect to Artimus HVPS
    ch1 = psu.channels['ch1'] # add single output channel
    max_voltage = 6000 # [V]
    sample_rate = 1000; # [Hz]

    # psu.ask('hardware'); # check firmware

    # Collect user input
    while True:
        print("Select output signal")
        print("0: Zero voltage")
        print("1: Sine")
        print("2: Square")
        print("3: Chirp")
        print("4: Heartbeat")
        print("5: Superimposed sines")
        print("6: Exit")
        
        user_input = input("Enter your choice (0-6): ")

        if user_input == '1':
            print("Sine waveform.")
            freq = 10 # [Hz]
            ch1.sin(freq, max_voltage) # output sine
        elif user_input == '2':
            print("Square waveform.")
            freq = 1 # [Hz]
            duty = 0.5 # [Hz]
            ch1.square(freq, max_voltage, duty) # output square
        elif user_input == '3':
            print("Chirp waveform.")
            f0 = 0.2 # [Hz]
            f1 = 50 # [Hz]
            T = 2 # [s]
            dc_offset = 2000 # [V]
            outputChirp(ch1, sample_rate, f0, f1, T, max_voltage, dc_offset)
            #ch1.chirp(f0, f1, T, max_voltage) # output chirp, with 'bounce'
        elif user_input == '4':
            print("Heartbeat waveform.")
            voltage_lub = 4500 # [V]
            dc_offset = 2000 # [V]
            outputHeartbeat(ch1, sample_rate, max_voltage, voltage_lub, dc_offset)
        elif user_input == '5':
            print("Superimposed waveform.")
            f1 = 50 # [Hz]
            max_voltage_f1 = 1000 # [Hz]
            f0 = 1 # [Hz]
            dc_offset = 0 # [V]
            max_voltage_f0 = max_voltage-max_voltage_f1-dc_offset # [Hz]
            outputSuperimposed(ch1, sample_rate, f0, f1, max_voltage_f0, max_voltage_f1, dc_offset)
        elif user_input == '0':
            print("Zero output.")
            ch1.zero()
        elif user_input == '6':
            print("Exiting...")
            ch1.zero()
            break
        else:
            print("Invalid input. Please enter a number between 0 and 6.")

if __name__ == "__main__":
    main()
