#pragma once

#include <neopixel.h>
#include "cycleCounter.h"
#include "valueslider.h"
#include "vector.h"

using Norman::NeoPixel;
using Norman::Vector;

/**
Generic representation of an effect that can be applied to
a NeoPixel strip.

Author: N. Streifling

Date: July 4, 2016

Version: 1.0.0
*/
class PixelEffect
{
public:

	/**
	Return codes from applyEffect().
	*/
	enum class ProcessingStatus
	{
		/** Indicates the affect was applied. */
		HAS_BEEN_PROCESSED,

		/** Indicates the effect was skipped. */
		NOT_PROCESSED
	};

	/**
	Possibly applies the effect to a NeoPixel LED strip.
	Implementaitons have the option to decide to not do
	anything when this function is called.

	Params:
	neoPixel= The NeoPixel object to apply an effect to.
	numberOfLitLEDs= Source of the number of LEDs that will
		be turned on on the NeoPixel strip.
	baseColor= The color that the LED strip would be flood
		filled if no color-altering effect was used.
	*/
	virtual ProcessingStatus
	applyEffect(
			NeoPixel&           neoPixel,
			ValueSlider&        numberOfLitLEDs,
			const NeoPixel::RGB baseColor) = 0;
};

/*=======================================================*\
|  PixelEffect Implementations:  |
\*==============================*/

/**
Simply applies the base color to the length specified
by the ValueSlider.

Author: N. Streifling

Date: July 4, 2016

Version 1.0.0
*/
class ApplyColorPixelEffect
		: public PixelEffect
{
public:
	/**
	Causes the LED strip to be flood filled.  This effect
	will always be applied when this function is called.
	*/
	ProcessingStatus
	applyEffect(
			NeoPixel&           neoPixel,
			ValueSlider&        numberOfLitLEDs,
			const NeoPixel::RGB baseColor);
};

/**
Creates a rainbow effect overlayed on top of the existing pixel
colors.  The rainbow moves across the lit pixels over time.

Author: N. Streifling

Date: July 4, 2016

Version: 1.0.0
*/
class AuroraPixelEffect
		: public PixelEffect
{
public:

	/**
	Params:
	minLitPixels= The minimum number of pixels that must be
		lit up for this effect to trigger.
	cycleCounter= Used to tell how far to shift the effect
		down the NeoPixel strip.  As this object's internal
		value changes over time, so will the rainbow move
		down the LED strip.
	*/
	AuroraPixelEffect(
			const size_t  minLitPixels,
			CycleCounter& cycleCounter);

	/**
	If the ValueSlider indicates that the minimum number of
	LEDs will be lit (specified in the constructor), then
	this will make a rainbow effect that will move with the
	value of the cycleCounter (also given in the
	constructor) and is tinted the base color.
	*/
	ProcessingStatus
	applyEffect(
			NeoPixel&           neoPixel,
			ValueSlider&        numberOfLitLEDs,
			const NeoPixel::RGB baseColor);

protected://=================

	static constexpr float  _rainbowAlpha  = 0.5f;
	static constexpr size_t _rainbowLength = 12;
	static constexpr uint8_t
			_colorWheelAdvanceAmountPerLED =
					255.0f / _rainbowLength;

	const size_t  _minLitPixels;
	CycleCounter& _cycleCounter;

	//=======================

	/*Adapted from the NeoPixel example code.*/
	static
	NeoPixel::RGB colorWheel(
			uint8_t wheelPosition);
};

/**
An effect that makes the lit pixels pulse red when the
number of lit pixels falls below a threashold.

Author: N. Streifling

Date: July 4, 2016

Version: 1.0.0
*/
class CriticalPulsePixelEffect
		: public PixelEffect
{
public:

	/**
	Params:
	maxLitPixels= If the number of lit pixels is greatter
		than this value, then this effect will not be
		applied.
	cycleCounter= Used to determine how much red tint to
		apply to the base color at the given point in
		time.
	*/
	CriticalPulsePixelEffect(
			const size_t  maxLitPixels,
			CycleCounter& cycleCounter);

	/**
	If the number of lit pixels (indicated by the
	ValueSlider) is less than or equal to the maximum
	threshold, then this will apply the red pulsing
	effect.
	*/
	ProcessingStatus
	applyEffect(
			NeoPixel&           neoPixel,
			ValueSlider&        numberOfLitLEDs,
			const NeoPixel::RGB baseColor);

protected://=================

	/*This is how red the color will turn when the cycle percentage
	reaches 0.5f.*/
	static constexpr float _maxAlpha = 0.85f;

	const size_t  _maxLitPixels;
	CycleCounter& _cycleCounter;
};

/**
Once triggured, this will create an effect where the light level
scrolls up the pixel strip (with each clock tick) and then can
oscillate around the end point.  This will take over control of
the ValueSlider.  Unlike the other PixelEffects, this one
cannot be reused accross multiple LED strips; there must be
a dedicated instantiation for each strip.

Author: N. Streifling

Date: April 17, 2016

Version: 1.0.0
*/
class StartupScrollEffect
		: public PixelEffect
{
public:

	/**
	The starting color will correspond to the starting position.
	The color of the ending position will be the base color
	provided through applyEffect().
	*/
	StartupScrollEffect(
			const size_t        startPosition,
			const NeoPixel::RGB startColor);

	//=======================

	/**
	Add a point that the effect will scroll to before moving to
	the ending position.  These oscillation points will be used
	in the order that they are specified.
	*/
	StartupScrollEffect&
	addOscillationPoint(
			const size_t point);

	/**
	This effect will not happen unless this function is called,
	then it cannot be stopped until it has run though.
	*/
	void triggureEffectToHappen();

	///
	ProcessingStatus
	applyEffect(
			NeoPixel&           neoPixel,
			ValueSlider&        numberOfLitLEDs,
			const NeoPixel::RGB baseColor);

protected:

	/*Stores all the scrolling points.*/
	Vector<size_t> _oscillationSequencePoints;

	/*Used to determine if the effect should run.*/
	bool _effectIsNotRunning;

	size_t _currentVectorIndex;
	size_t _currentLitLEDs;

	/*Used for mixing colors.*/
	NeoPixel::RGB _startColor;
	size_t  _startPoint, _endPoint;
};
