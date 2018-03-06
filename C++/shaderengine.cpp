#include <assert.h>
#include "shaderengine.h"

using namespace Norman;

/*======================*\
|  PriorityShaderEngine  |
|  public:               |
\*======================*/

PriorityShaderEngine& PriorityShaderEngine::addPixelEffect(
		PixelEffect* pixelEffect)
{
	_effects.append(pixelEffect);
	return *this;
}

NeoPixel& PriorityShaderEngine::shadePixels(
		NeoPixel&           neoPixel,
		ValueSlider&        numberOfLitLEDs,
		const NeoPixel::RGB baseColor)
{
	for(size_t j = 0; j < _effects.length(); j++)
	{
		const auto processed = _effects[j]->applyEffect(
				neoPixel, numberOfLitLEDs, baseColor);

		if(processed == PixelEffect::ProcessingStatus
				::HAS_BEEN_PROCESSED)
			return neoPixel;
	}

	return neoPixel;
}
