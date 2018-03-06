#include <assert.h>
#include <math.h>
#include "neopixelutil.h"
#include "pixeleffects.h"

using namespace Norman;

/*=========================================================
|  ApplyColorPixelEffect  |
\*=======================*/

PixelEffect::ProcessingStatus
ApplyColorPixelEffect::applyEffect(
		NeoPixel&           neoPixel,
		ValueSlider&        numberOfLitLEDs,
		const NeoPixel::RGB baseColor)
{
	floodFill(neoPixel, numberOfLitLEDs.getValue(), baseColor);
	return ProcessingStatus::HAS_BEEN_PROCESSED;
}

/*=========================================================
|  AuroraPixelEffect  |
|=====================|
|  public:            |
\*===================*/

AuroraPixelEffect::AuroraPixelEffect(
		const size_t  minLitPixels,
		CycleCounter& cycleCounter) :
_minLitPixels(minLitPixels),
_cycleCounter(cycleCounter)
{}

PixelEffect::ProcessingStatus
AuroraPixelEffect::applyEffect(
		NeoPixel&           neoPixel,
		ValueSlider&        numberOfLitLEDs,
		const NeoPixel::RGB baseColor)
{
	const size_t litPixels  = numberOfLitLEDs.getValue();
	if(litPixels < _minLitPixels)
		return ProcessingStatus::NOT_PROCESSED;

	const float  cycleValue =
			_cycleCounter.getUnidirectionalValue();

	//--

	for(size_t j = 0; j < litPixels; j++)
	{
		uint8_t colorWheelPosition = cycleValue * 255 +
				j * _colorWheelAdvanceAmountPerLED;

		neoPixel.setPixelColor(j,
				colorBlend(_rainbowAlpha, baseColor,
						colorWheel(colorWheelPosition)));
	}

	return ProcessingStatus::HAS_BEEN_PROCESSED;
}

/*=========================================================
|  AuroraPixelEffect  |
|=====================|
|  protected:         |
\*===================*/

NeoPixel::RGB AuroraPixelEffect::colorWheel(
		uint8_t  wheelPosition)
{
	wheelPosition = 255 - wheelPosition;

	NeoPixel::RGB color;

	if(wheelPosition < 85)
	{
		color.r = 255 - wheelPosition * 3;
		color.g = 0;
		color.b = wheelPosition * 3;
	}else if(wheelPosition < 170)
	{
		wheelPosition -= 85;

		color.r = 0;
		color.g = wheelPosition * 3;
		color.b = 255 - wheelPosition * 3;
	}else
	{
		wheelPosition -= 170;

		color.r = wheelPosition * 3;
		color.g = 255 - wheelPosition * 3;
		color.b = 0;
	}

	return color;
}

/*=========================================================
|  CriticalPulsePixelEffect  |
\*==========================*/

CriticalPulsePixelEffect::CriticalPulsePixelEffect(
			const size_t  maxLitPixels,
			CycleCounter& cycleCounter) :
_maxLitPixels(maxLitPixels),
_cycleCounter(cycleCounter)
{}

PixelEffect::ProcessingStatus
CriticalPulsePixelEffect::applyEffect(
		NeoPixel&           neoPixel,
		ValueSlider&        numberOfLitLEDs,
		const NeoPixel::RGB baseColor)
{
	static const NeoPixel::RGB red = {255, 0, 0};

	const size_t litPixels = numberOfLitLEDs.getValue();
	if(litPixels > _maxLitPixels)
		return ProcessingStatus::NOT_PROCESSED;

	const float pulseAlpha =
			_cycleCounter.getOscillatingValue() * _maxAlpha;

	//--

	floodFill(neoPixel, litPixels,
			colorBlend(pulseAlpha, baseColor, red));

	return ProcessingStatus::HAS_BEEN_PROCESSED;
}

/*=========================================================
|  StartupScrollEffect  |
\*=====================*/

StartupScrollEffect::StartupScrollEffect(
		const size_t        startPosition,
		const NeoPixel::RGB startColor) :
_effectIsNotRunning(true),
_currentVectorIndex(0),
_currentLitLEDs(0),
_startColor(startColor),
_startPoint(startPosition),
_endPoint(startPosition)
{
	_oscillationSequencePoints.append(startPosition);
}

//===========================

StartupScrollEffect&
StartupScrollEffect::addOscillationPoint(
		const size_t point)
{
	_oscillationSequencePoints.append(point);
	_endPoint = point;
	return *this;
}

void
StartupScrollEffect::triggureEffectToHappen()
{
	_effectIsNotRunning = false;
	_currentVectorIndex = 0;
	_currentLitLEDs = _oscillationSequencePoints[0];
	return;
}

PixelEffect::ProcessingStatus
StartupScrollEffect::applyEffect(
		NeoPixel&           neoPixel,
		ValueSlider&        numberOfLitLEDs,
		const NeoPixel::RGB baseColor)
{
	if(_effectIsNotRunning)
		return ProcessingStatus::NOT_PROCESSED;

	assert(_currentVectorIndex <
			_oscillationSequencePoints.length());

	if(_currentLitLEDs == _oscillationSequencePoints[
			_currentVectorIndex])
	{
		_currentVectorIndex++;
		if(_currentVectorIndex >=
				_oscillationSequencePoints.length())
		{
			_effectIsNotRunning = true;
			return ProcessingStatus::NOT_PROCESSED;
		}
	}

	if(_currentLitLEDs < _oscillationSequencePoints[
			_currentVectorIndex])
		_currentLitLEDs++;
	else
	{
		assert(_currentLitLEDs > _oscillationSequencePoints[
				_currentVectorIndex]);
		_currentLitLEDs--;
	}
	numberOfLitLEDs.setValue(_currentLitLEDs);

	float blendStop = static_cast<float>(
					_currentLitLEDs - _startPoint)
			/ (_endPoint - _startPoint);
	NeoPixel::RGB mixColor = colorBlend(
			blendStop, _startColor, baseColor);
	floodFill(neoPixel, _currentLitLEDs, mixColor);

	return ProcessingStatus::HAS_BEEN_PROCESSED;
}//applyEffect
