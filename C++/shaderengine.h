#pragma once

#include <neopixel.h>
#include "pixeleffects.h"
#include "valueslider.h"
#include "vector.h"

/**
Aggregates PixelEffects such that only one will apply an
effect on any particular run (whichever applies it's effect
first).  The PixelEffects will be tried in the order in
which they were given to the PriorityShaderEngine object.

Author: N. Streifling

Date: July 3, 2016

Version: 1.0.0
*/
class PriorityShaderEngine
{
public:

	/**
	Add an effect generator to the internal list.  Note
	that this works like a queue: the first effect added
	will be the first polled to see if it will apply its
	effect.
	*/
	PriorityShaderEngine& addPixelEffect(
			PixelEffect* pixelEffect);

	/**
	Apply a shading effect to the NeoPixel strip.
	*/
	Norman::NeoPixel& shadePixels(
			Norman::NeoPixel&   neoPixel,
			ValueSlider&        numberOfLitLEDs,
			const NeoPixel::RGB baseColor);

protected://=================

	/*All of the PixelEffects.*/
	Norman::Vector<PixelEffect*> _effects;
};
