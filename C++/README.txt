The files here are taken from an Arduino project that controls
the output values of a pair of LED strips.  The pixeleffects
library contains several classes that look at a ValueSlider
object to determine what state the system is in, decide if
their effect will be applied to the LED output, and then set
the individual LED outputs.  Objects made from these classes
are fed into the PriorityShaderEngine, which runs a list of
PixelEffects until one applies itself.

For example:  If the CriticalPulsePixelEffect finds that the
ValueSlider indicates that the number of LEDs that are
currently lit are less than a threshold value, then the
object will cause the LEDs to oscillate between their
base color and red.
