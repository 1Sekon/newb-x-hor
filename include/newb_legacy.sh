//// Legacy code ported from newb-shader-mcbe
//// !! depreciated !!

bool detectEnd(vec3 FOG_COLOR){
	// end is given a custom fog color in biomes_client.json to help in detection
	// dark color (issue- rain transition when entering end)
	return FOG_COLOR.r==FOG_COLOR.b && FOG_COLOR.r > 0.1  && FOG_COLOR.g < FOG_COLOR.r*0.4;
}

bool detectNether(vec3 FOG_COLOR, vec2 FOG_CONTROL){
	// FOG_CONTROL x and y varies with renderdistance
	// x range (0.03,0.14)

	// reverse plotted relation (5,6,7,8,9,11,12,20,96 chunks data) with an accuracy of 0.02
	float expectedFogX = 0.029 + (0.09*FOG_CONTROL.y*FOG_CONTROL.y);	// accuracy of 0.015

	// nether wastes, basalt delta, crimson forest, wrapped forest, soul sand valley
	bool netherFogCtrl = (FOG_CONTROL.x<0.14  && abs(FOG_CONTROL.x-expectedFogX) < 0.02);
	bool netherFogCol = (FOG_COLOR.r+FOG_COLOR.g)>0.0;

	// consider underlava as nether
	bool underLava = FOG_CONTROL.x==0.0 && FOG_COLOR.b==0.0 && FOG_COLOR.g<0.18 && FOG_COLOR.r-FOG_COLOR.g>0.1;

	return (netherFogCtrl && netherFogCol) || underLava;
}

bool detectUnderwater(vec3 FOG_COLOR, vec2 FOG_CONTROL){
	return FOG_CONTROL.x<0.001 && max(FOG_COLOR.b,FOG_COLOR.g)>FOG_COLOR.r;
}

float detectRain(float RENDER_DISTANCE, vec2 FOG_CONTROL){
	// FOG_CONTROL values when clear/rain
	// clear FOG_CONTROL.x varies with RENDER_DISTANCE
	// reverse plotted (low accuracy) as 0.5 + 1.09/(k-0.8) where k is renderdistance in chunks
	// remaining values are equal to those specified in json file
	vec2 start = vec2(0.5 + (1.09/((RENDER_DISTANCE*0.0625)-0.8)),0.99);
	const vec2 end = vec2(0.2305,0.7005);

	vec2 factor = clamp((start-FOG_CONTROL)/(start-end),vec2(0.0),vec2(1.0));

	// ease in ease out for Y
	factor.y = factor.y*factor.y*(3.0 - 2.0*factor.y);

	return factor.x*factor.y;
}

// 1D noise - used in plants,lantern wave
highp float noise1D(highp float x){
	float x0 = floor(x);
	float t0 = x-x0;
	t0 *= t0*(3.0-2.0*t0);
	return mix(fract(sin(x0)*84.85),fract(sin(x0+1.0)*84.85),t0);
}

// hash function for noise (for highp only)
highp float rand(highp vec2 n){
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

// interpolation of noise - used by rainy air blow
// see https://thebookofshaders.com/11/
float noise2D(vec2 p){
	vec2 p0 = floor(p);
	vec2 u = p-p0;

	u *= u*(3.0-2.0*u);
	vec2 v = 1.0 - u;

	float c1 = rand(p0);
	float c2 = rand(p0+vec2(1.0,0.0));
	float c3 = rand(p0+vec2(0.0,1.0));
	float c4 = rand(p0+vec2(1.0));

	float n = v.y*(c1*v.x+c2*u.x) + u.y*(c3*v.x+c4*u.x);

	return min(n*n,1.0);
}

// Toggle - Flip time after 1800 seconds
// Disable this if you have static wave bug
#define TIME_FLIPPING

// Value - Sunlight brightness
#define sun_intensity 2.95

// Type - Fog type
// 0 - Off
// 1 - Vanilla fog
// 2 - Smoother vanilla fog (Default)
#define FOG_TYPE 2

// Value - Density of mist
#define mist_density 0.18

vec4 renderMist(vec3 fog, float dist, float lit, float rain, bool nether, bool underwater, bool end, vec3 FOG_COLOR){

	float density = mist_density;
	if(!(nether||end)){
		// increase density based on darkness
		density += density*(0.99-FOG_COLOR.g)*18.0;
	}

	vec4 mist;
	if(nether){
		mist.rgb = FOG_COLOR.rgb;
		mist.rgb = mix(2.6*mist.rgb*mist.rgb,vec3(2.1,0.7,0.2),lit*0.7);
	}
	else{
		mist.rgb = fog*vec3(1.0,1.1-0.1*rain,1.4-0.4*rain);
	}

	// exponential mist
	mist.a = 0.31-0.3*exp(-dist*dist*density);

	if(underwater){
		mist.rgb = fog;
		mist.a = 0.2+0.5*min(dist*dist,1.0);
	}

	return mist;
}

vec4 renderFog(vec3 fogColor, float len, bool nether, vec3 FOG_COLOR, vec2 FOG_CONTROL){

#if FOG_TYPE > 0

	vec4 fog;
	if(nether){
		// inverse color correction
		fog.rgb = FOG_COLOR.rgb;
		fog.rgb = pow(fog.rgb,vec3(1.37));
		vec3 w = vec3(0.7966);
		fog.rgb = fog.rgb*(w + fog.rgb)/(w + fog.rgb*(vec3(1.0) - w));
	}
	else{ fog.rgb = fogColor; }

	fog.a = clamp( (len -  FOG_CONTROL.x)/(FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);

	#if FOG_TYPE > 1
		fog.a = (fog.a*fog.a)*(3.0-2.0*fog.a);
	#endif

	return fog;

#else
	return vec4(0.0);
#endif

}

// color - Night sky color
const vec3 nightSkyCol = vec3(0.01,0.06,0.1);

// color - Sky base color
const vec3 skyBaseCol = vec3(0.15,0.45,1.0);

// value - Day sky clarity (0-1)
const float daySkyClarity = 0.3;

// color - Sunrise base color
const vec3 horizonBaseCol = vec3(1.0,0.4,0.3);

// color - Sunrise edge color
const vec3 horizonEdgeCol = vec3(1.0,0.4,0.2);

// color - Underwater fog color
const vec3 underwaterBaseCol = vec3(0.0,0.6,1.0);

const vec3 horizonEdgeAbsCol = 1.0-horizonEdgeCol;

vec3 getUnderwaterCol(vec3 FOG_COLOR){
	return underwaterBaseCol*FOG_COLOR.b;
}

vec3 getZenithCol(float rainFactor, vec3 FOG_COLOR){

	// value needs tweaking
	float val = max(FOG_COLOR.r*0.6,max(FOG_COLOR.g,FOG_COLOR.b));

	// zenith color
	vec3 zenithCol = (0.77*val*val + 0.33*val)*skyBaseCol;
	zenithCol += nightSkyCol*(0.4-0.4*FOG_COLOR.b);

	// rain sky
	float brightness = min(FOG_COLOR.g,0.26);
	brightness *= brightness*13.2;
	zenithCol = mix(zenithCol*(1.0+0.5*rainFactor),vec3(0.85,0.9,1.0)*brightness,rainFactor);

	return zenithCol;
}

vec3 getHorizonCol(float rainFactor, vec3 FOG_COLOR){

	// value needs tweaking
	float val = max(FOG_COLOR.r*0.65,max(FOG_COLOR.g*1.1,FOG_COLOR.b));

	float sun = max(FOG_COLOR.r-FOG_COLOR.b,0.0);

	// horizon color
	vec3 horizonCol = horizonBaseCol*(((0.7*val*val) + (0.4*val) + sun)*2.4);

	horizonCol += nightSkyCol;

	horizonCol = mix(
		horizonCol,
		2.0*val*mix(vec3(0.7,1.0,0.9),skyBaseCol,daySkyClarity),
		val*val);

	// rain horizon
	float brightness = min(FOG_COLOR.g,0.26);
	brightness *= brightness*19.6;
	horizonCol = mix(horizonCol,vec3(brightness),rainFactor);

	return horizonCol;
}

vec3 getHorizonEdgeCol(vec3 horizonCol, float rainFactor, vec3 FOG_COLOR){
	float val = (1.1-FOG_COLOR.b)*FOG_COLOR.g*2.1;
	val *= 1.0-rainFactor;

	vec3 tint = vec3(1.0)-val*horizonEdgeAbsCol;
	return horizonCol*tint;
}

// sunlight tinting
vec3 sunLightTint(vec3 night_color,vec3 morning_color,vec3 day_color,float dayFactor,float rain, vec3 FOG_COLOR){

	float tintFactor = FOG_COLOR.g + 0.1*FOG_COLOR.r;
	float noon = clamp((tintFactor-0.37)/0.45,0.0,1.0);
	float morning = clamp((tintFactor-0.05)*3.125,0.0,1.0);

	float r = 1.0-rain;
	r *= r;

	return mix(vec3(0.65,0.65,0.75),mix(
		mix(night_color,morning_color,morning),
		mix(morning_color,day_color,noon),
		dayFactor),r*r);
}

// 1D sky with three color gradient
// A copy of this is in sky.fragment, make changes there aswell
vec3 renderSky(vec3 reddishTint, vec3 horizonColor, vec3 zenithColor, float h){
	h = 1.0-h*h;

	float hsq = h*h;

	// gradient 1  h^16
	// gradient 2  h^8 mix h^2
	float gradient1 = hsq*hsq*hsq*hsq;
	float gradient2 = 0.6*gradient1 + 0.4*hsq;
	gradient1 *= gradient1;

	horizonColor = mix(horizonColor, reddishTint, gradient1);
	return mix(zenithColor,horizonColor, gradient2 );
}

// Type - Tone mapping type
// 1 - Exponential
// 2 - Simple Reinhard
// 3 - Extended Reinhard (Default)
// 4 - ACES
#define TONEMAPPING_TYPE 3

// Toggle + Value - Exposure
//#define EXPOSURE 1.3

// Value - Contrast
#define CONTRAST 0.74

// Toggle + Value - Saturation
//#define SATURATION 1.4

// Toggle + Color - Tinting
//#define TINT vec3(1.0,0.75,0.5)

// see https://64.github.io/tonemapping/

#if TONEMAPPING_TYPE==3
// extended reinhard tonemapping
vec3 tonemap(vec3 x){
	//float white = 4.0;
	//float white_scale = 1.0/(white*white);
	float white_scale = 0.063;
	x = (x*(1.0+(x*white_scale)))/(1.0+x);
	return x;
}
#elif TONEMAPPING_TYPE==4
// aces tone mapping
vec3 tonemap(vec3 x){
	x *= 0.85;
	const float a = 1.04;
	const float b = 0.03;
	const float c = 0.93;
	const float d = 0.56;
	const float e = 0.14;
	return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}
#elif TONEMAPPING_TYPE==2
// simple reinhard tonemapping
vec3 tonemap(vec3 x){
	return x/(1.0 + x);
}
#elif TONEMAPPING_TYPE==1
// exponential tonemapping
vec3 tonemap(vec3 x){
	return 1.0-exp(-x*0.8);
}
#endif

vec3 colorCorrection(vec3 color){
	#ifdef EXPOSURE
		color *= EXPOSURE;
	#endif

	color = tonemap(color);

	// actually supposed to be gamma correction
	color = pow(color, vec3(CONTRAST));

	#ifdef SATURATION
		color = mix(vec3(dot(color,vec3(0.21, 0.71, 0.08))), color, SATURATION);
	#endif

	#ifdef TINT
		color *= TINT;
	#endif

	return color;
}

// Value - Cloud size when raining (0-1)
#define rain_cloud_size 0.9

// Value - Normal cloud size (0-1)
#define normal_cloud_size 0.27

// Value - Cloud map size (0-100)
#define cloud_noise_size 36.0

// Value - Cloud depth (0-3)
#define cloud_depth 1.3

// Value - Cloud movement speed
#define cloud_speed 0.04

// Value - Cloud shadow intensity (0-1)
#define cloud_shadow 0.54

// Value - Cloud transparency (0-1)
#define cloud_alpha 0.8

//️ Toggle - Enable aurora effect for night sky
//️ Value - Aurora borealis brightness
#define AURORA 1.0

const vec2 cloud_size = vec2(0.7,1.0)/cloud_noise_size;

const float start_rain = 1.0-rain_cloud_size;
const float start_normal = 1.0-normal_cloud_size;

// clamp rand for cloud noise
highp float rand01(highp vec2 seed,float start){
	float result = rand(seed);
	result = clamp((result-start)*3.4,0.0,1.0);
	return result*result;
}

// 2D cloud noise - used by clouds
float cloudNoise2D(vec2 p, highp float t, float rain){

	t *= cloud_speed;

	// start threshold - for bigger clouds during rain
	float start = start_normal + (normal_cloud_size)*(0.1+0.1*sin(t + p.y*0.3));
	start = mix(start,start_rain,rain);

	p += vec2(t);
	p.x += sin(p.y*0.4 + t);

	vec2 p0 = floor(p);
	vec2 u = p-p0;

	u *= u*(3.0-2.0*u);
	vec2 v = 1.0-u;

	float c1 = rand01(p0,start);
	float c2 = rand01(p0+vec2(1.0,0.0),start);
	float c3 = rand01(p0+vec2(0.0,1.0),start);
	float c4 = rand01(p0+vec2(1.0),start);

	return v.y*(c1*v.x+c2*u.x) + u.y*(c3*v.x+c4*u.x);
}

// simple cloud
vec4 renderClouds(vec4 color, vec2 uv, highp float t, float rain){

	float cloudAlpha = cloudNoise2D(uv,t,rain);
	float cloudShadow = cloudNoise2D(uv,(t+0.16),rain)*0.2;

	cloudAlpha = max(cloudAlpha-cloudShadow,0.0);

	// rainy clouds color
	color.rgb = mix(color.rgb,vec3(0.7),rain*0.5);

	// highlight at edge
	color.rgb += vec3(0.6,0.6,1.0)*(0.2-cloudShadow);

	// cloud shadow
	color.rgb *= (1.0-cloudShadow*3.0*cloud_shadow);

	return vec4(color.rgb,cloudAlpha);
}

// simple northern night sky effect
vec4 renderAurora(vec2 uv, highp float t, float rain){
	float auroraCurves = sin(uv.x*0.09 + 0.07*t) + 0.3*sin(uv.x*0.5 + 0.09*t) + 0.03*sin((uv.x+uv.y)*3.0 + 0.2*t);
	float auroraBase = uv.y*0.4 + 2.0*auroraCurves;
	float auroraFlow = 0.5+0.5*sin(uv.x*0.3 + 0.07*t + 0.7*sin(auroraBase*0.9) );

	float auroraCol = sin(uv.y*0.06 + 0.07*t);
	auroraCol = abs(auroraCol*auroraCol*auroraCol);

	float aurora = sin(auroraBase)*sin(auroraBase*0.3);
	aurora = abs(aurora*auroraFlow);

	return vec4(
		0.0,
		(1.0-auroraCol)*aurora,
		auroraCol*aurora,
		aurora*aurora*(0.5-0.5*rain) );
}

// Toggle - Flickering torch light
//#define BLINKING_TORCH

// Toggle - God rays (incomplete)
//#define GOD_RAYS

// Value - Change to 0.87 to fix slab bug (makes shadow smaller)
#define shadow_edge 0.876

// Value - Intensity of soft shadow (0-1)
#define shadow_intensity 0.7

// Value - Night extra brightness
#define night_brightness 0.1

// Value - Cave extra brightness
#define cave_brightness 0.1

// Value - Torch brightness
#define torch_intensity 1.0

// Color - Top light color (Sunlight color)
const vec3 morning_color = vec3(1.0,0.45,0.14);
const vec3 noon_color = vec3(1.0,0.75,0.57);
const vec3 night_color = vec3(0.5,0.64,1.0);

// Color - Torch light color
const vec3 overworld_torch = vec3(1.0,0.52,0.18);
const vec3 underwater_torch = vec3(1.0,0.52,0.18);
const vec3 nether_torch = vec3(1.0,0.52,0.18);
const vec3 end_torch = vec3(1.0,0.52,0.18);

// Toggle - Plants Wave (leaves/plants)
// Value - Wave animation intensity (Plants)
#define PLANTS_WAVE 0.04

// Toggle - Lantern swing
// Value - Lantern swing intensity (0-0.6)
#define LANTERN_WAVE 0.16

// Toggle - Non-transparent leaves wave (might cause white lines at edges)
//#define ALL_LEAVES_WAVE

// Toggle - Extra plants Wave for 1.18 (won't work with add-ons which add new blocks)
//#define EXTRA_PLANTS_WAVE

// Value - Wave animation speed (Plants,leaves)
#define wave_speed 2.8

// Value - Rainy wind blow transparency (0-0.3)
#define rain_blow_opacity 0.19

// Toggle - Water wave
// Value - Wave intensity of water surface
#define WATER_WAVE 0.02

// Toggle - Cloud reflection on water
#define CLOUD_REFLECTION

// Toggle - Use only surface angle for water transparency fade (gives more transparency)
//#define USE_ANGLE_BLEND_FADE

// Value - Water transparency (0-1)
#define water_transparency 0.47

// Value - Water noise bump height (0-0.2)
#define water_bump 0.07

// Color - Water color
const vec3 sea_water_color = vec3(0.13,0.65,0.87);
const vec3 fresh_water_color = vec3(0.07,0.55,0.55);
const vec3 marshy_water_color = vec3(0.27,0.4,0.1);

// Value - Water texture overlay
#define WATER_TEX_OPACITY 0.0

// Toggle - Underwater Wave
// Value - Wave intensity
#define UNDERWATER_WAVE 0.06

// Toggle - Wave effect above water surface when underwater
//#define WAVE_ABOVE_WATER

// Value - Underwater brightness
#define underwater_brightness 0.8

// Value - Underwater soft caustic intensity
#define caustic_intensity 2.5

// Color - Underwater lighting color
const vec3 underwater_color = vec3(0.2,0.6,1.0);

const float rd = 1.57079; // pi by 2
const float shadowIntensity = 1.0-shadow_intensity;

// bool between function
bool is(float val,float val1,float val2){
	return (val>val1 && val<val2);
}

// water transparency
float getWaterAlpha(vec3 col){
	// tint - col.r,
	vec2 val = vec2(0.9,water_transparency); // swamp, fresh

	return col.r<0.5 ? mix(val.x,val.y,col.r*2.0) : val.y;
}

// simpler rand for disp,wetmap
float fastRand(vec2 n){
	float a = cos( dot(n,vec2(4.2683,1.367)) );
	float b = dot( n,vec2(1.367,4.683) );
	return fract(a+b);
}

// water displacement map (also used by caustic)
float disp(vec3 pos, highp float t){
	float val = 0.5 + 0.5*sin(t*1.7+((pos.x+pos.y)*rd));
	return mix(fastRand(pos.xz),fastRand(pos.xz+vec2(1.0)),val);
}

// sky reflection on plane - used by water, wet reflection
vec3 getSkyRefl(vec3 horizonEdge, vec3 horizon, vec3 zenith, float y, float h){

	// offset the reflection based on height from camera
	float offset = h/(50.0+h); 	// (h*0.02)/(1.0+h*0.02)
	y = max((y-offset)/(1.0-offset),0.0);

	return renderSky(horizonEdge, horizon, zenith, y);
}

// simpler sky reflection for rain
vec3 getRainSkyRefl(vec3 horizon, vec3 zenith, float h){

	h = 1.0-h*h;
	float hsq = h*h;

	return mix(zenith,horizon,hsq*hsq);
}

// sunrise/sunset reflection
vec3 getSunRefl(float viewDirX, float fog_brightness, vec3 FOG_COLOR){
	float sunRefl = clamp((abs(viewDirX)-0.9)/0.099,0.0,1.0);
	float factor = FOG_COLOR.r/length(FOG_COLOR.rgb);
	factor *= factor;
	sunRefl *= sunRefl*sunRefl*factor*factor;
	sunRefl *= sunRefl;
	return (fog_brightness*sunRefl)*vec3(2.5,1.6,0.8);
}

// fresnel - Schlick's approximation
float calculateFresnel(float cosR, float r0){
	float a = 1.0-cosR;

	float a5 = a*a;
	a5 *= a5*a;

	return r0 + (1.0-r0)*a5;
	//return r0 + (1.0-r0)*exp(-6.0*cosR);
}


//// Implementation


vec3 nl_lighting(vec3 COLOR, vec3 FOG_COLOR, float rainFactor, vec2 uv1, bool isTree,
                 vec3 horizonCol, vec3 zenithCol, float shade, bool end, bool nether) {
    // Lighting
    // all of these will be multiplied by tex uv1 in frag so functions should be divided by uv1 here
    vec3 light;
    vec2 lit = uv1*uv1;
#ifdef UNDERWATER
	torchColor = underwater_torch;
#endif
    float torch_attenuation = (torch_intensity*uv1.x)/(0.5-0.45*lit.x);
#ifdef BLINKING_TORCH
	torch_attenuation *= 1.0 - 0.19*noise1D(t*8.0);
#endif
    vec3 torchColor = end ? end_torch : (nether ? nether_torch : overworld_torch);
    vec3 torchLight = torchColor*torch_attenuation;

    if(nether || end){
        // nether & end lighting

        // ambient - end and nether
        light = end ? vec3(1.98,1.25,2.3) : vec3(1.98,1.44,1.26);

        // torch light
        light += torchLight;
    }
    else{
        // overworld lighting

        float dayFactor = min(dot(FOG_COLOR.rgb,vec3(0.5,0.4,0.4))*(1.0 + 1.9*rainFactor),1.0);
        float nightFactor = 1.0-dayFactor*dayFactor;
        float rainDim = min(FOG_COLOR.g,0.25)*rainFactor;
        float lightIntensity = sun_intensity*(1.0 - rainDim)*(1.0 + night_brightness*nightFactor);

        // min ambient in caves
        light = vec3((1.35+cave_brightness)*(1.0-uv1.x)*(1.0-uv1.y));

        // sky ambient
        light += mix(horizonCol,zenithCol,0.5+uv1.y-0.5*lit.y)*(lit.y*(3.0-2.0*uv1.y)*(1.3 + (4.0*nightFactor) - rainDim));

        // shadow cast by top light
        float shadow = float(uv1.y > shadow_edge);

        // make shadow a bit softer and more softer when raining
        shadow += uv1.y > 0.85 ? (0.2+0.3*rainFactor)*(1.0-shadow) : 0.0;

        shadow = max(shadow,(shadowIntensity + (0.6*shadow_intensity*nightFactor))*lit.y);
        shadow *= shade>0.8 ? 1.0 : 0.8;

        // direct light from top
        float dirLight = shadow*(1.0-uv1.x*nightFactor)*lightIntensity;
        light += dirLight*sunLightTint(night_color,morning_color,noon_color,dayFactor,rainFactor,FOG_COLOR);

        // extra indirect light
        light += vec3(0.3*lit.y*uv1.y*(1.2-shadow)*lightIntensity);

        // torch light
        light += torchLight*(1.0-(max(shadow,0.65*lit.y)*dayFactor*(1.0-0.3*rainFactor)));
    }

    // darken at crevices
    light *= COLOR.g > 0.35 ? 1.0 : 0.8;

    // brighten tree leaves
    if(isTree){light *= 1.25;}

    return light;
}

vec4 nl_water(vec4 color, vec3 light, vec3 wPos, vec3 cPos, vec4 COLOR, vec3 FOG_COLOR, vec3 horizonCol,
			  vec3 horizonEdgeCol, vec3 zenithCol, vec2 uv1, float t, float camDist,
			  float rainFactor, vec3 tiledCpos, bool end, vec3 torchColor) {
	vec3 viewDir = -wPos/camDist;
	// this is used for finding the type of plane
	float fractCposY = fract(cPos.y);

	// get water color (r-tint,g-lightness)
	vec3 waterCol = fresh_water_color;
	waterCol = COLOR.r < 0.5 ? mix(marshy_water_color,waterCol,COLOR.r*2.0) : mix(waterCol,sea_water_color,(COLOR.r*2.0)-1.0);
	waterCol *= COLOR.g;

	waterCol *= 0.3 + (FOG_COLOR.g*(2.0-2.0*FOG_COLOR.g)*rainFactor);
	waterCol *= light*max(max(FOG_COLOR.b,0.2+uv1.x*uv1.x),FOG_COLOR.r*1.2)*max(0.3+0.7*uv1.y,uv1.x);

	float cosR;
	vec3 waterRefl;

	// reflection for top plane
	if( fractCposY > 0.0 ){

		// calculate cosine of incidence angle and apply water bump
		float bump = disp(tiledCpos,t) + 0.12*sin(t*2.0 + dot(cPos,vec3(rd)));
		bump *= water_bump;
		cosR = abs(viewDir.y);
		cosR = mix(cosR,(1.0-cosR*cosR),bump);

		// sky reflection
		waterRefl = getSkyRefl(horizonEdgeCol,horizonCol,zenithCol,cosR,-wPos.y);
		waterRefl += getSunRefl(viewDir.x,horizonEdgeCol.r, FOG_COLOR);

		// sky,cloud reflection mask
		if(uv1.y < 0.93 && !end){waterRefl *= 0.7*uv1.y;}

		// ambient,torch light reflection
		waterRefl += vec3(0.02-(0.02*uv1.y)) + torchColor*torch_intensity*((uv1.x>0.83 ? 0.6 : 0.0) + uv1.x*uv1.x*bump*10.0);

		// flat plane
		if( is(fractCposY,0.8,0.9) ){ waterRefl *= 1.0 - 0.66*clamp(wPos.y,0.0,1.0); }

		// slanted plane and highly slanted plane
		else{ waterRefl *= (0.1*sin(t*2.0+cPos.y*12.566)) + (fractCposY > 0.9 ? 0.2 : 0.4);}
	}
	// reflection for side plane
	else{
		cosR = max(sqrt(dot(viewDir.xz,viewDir.xz)),float(wPos.y<0.5));
		cosR += (1.0-cosR*cosR)*water_bump*(0.5 + 0.5*sin(1.5*t + dot(cPos,vec3(rd)) ));

		waterRefl = zenithCol*uv1.y*uv1.y*1.3;
	}

	float fresnel = calculateFresnel(cosR,0.03);
	float opacity = 1.0-cosR;

	#ifdef USE_ANGLE_BLEND_FADE
		color.a = getWaterAlpha(COLOR.rgb) + opacity*(1.0-color.a);
	#else
		color.a = color.a + (1.0-color.a)*opacity*opacity;
	#endif

	color.rgb = waterCol*(1.0-0.4*fresnel) + waterRefl*fresnel;

	return color;
}
