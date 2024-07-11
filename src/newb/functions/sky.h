#ifndef SKY_H
#define SKY_H

// rainbow spectrum
vec3 spectrum(float x) {
    vec3 s = vec3(x-0.5, x, x+0.5);
    s = smoothstep(1.0,0.0,abs(s));
    return s*s;
}

vec3 getUnderwaterCol(vec3 FOG_COLOR) {
  return 1.4*NL_UNDERWATER_TINT*FOG_COLOR;
}

vec3 getEndZenithCol() {
  return NL_END_ZENITH_COL;
}

vec3 getEndHorizonCol() {
  return NL_END_HORIZON_COL;
}

// values used for getting sky colors
vec3 getSkyFactors(vec3 FOG_COLOR) {
  vec3 factors = vec3(
    max(FOG_COLOR.r*0.6, max(FOG_COLOR.g, FOG_COLOR.b)), // intensity val
    1.5*max(FOG_COLOR.r-FOG_COLOR.b, 0.0), // viewing sun
    min(FOG_COLOR.g, 0.26) // rain brightness
  );

  factors.z *= factors.z;

  return factors;
}

vec3 getZenithCol(float rainFactor, vec3 FOG_COLOR, vec3 fs) {
/*  vec3 zenithCol = NL_NIGHT_ZENITH_COL*(1.0-FOG_COLOR.b);
  zenithCol += NL_DAWN_ZENITH_COL*((0.7*fs.x*fs.x) + (0.4*fs.x) + fs.y);
  zenithCol = mix(zenithCol, (0.7*fs.x*fs.x + 0.3*fs.x)*NL_DAY_ZENITH_COL, fs.x*fs.x);*/
  
  vec3 zenithCol = mix(mix(NL_DAY_ZENITH_COL, NL_DAWN_ZENITH_COL, duskD(FOG_COLOR)), NL_NIGHT_ZENITH_COL, nightD(FOG_COLOR));
  
  zenithCol = mix(zenithCol*(1.0+0.5*rainFactor), NL_RAIN_ZENITH_COL*fs.z*13.2, rainFactor);

  return zenithCol;
}

vec3 getHorizonCol(float rainFactor, vec3 FOG_COLOR, vec3 fs) {
/*  vec3 horizonCol = NL_NIGHT_HORIZON_COL*(1.0-FOG_COLOR.b); 
  horizonCol += NL_DAWN_HORIZON_COL*(((0.7*fs.x*fs.x) + (0.3*fs.x) + fs.y)*1.9); 
  horizonCol = mix(horizonCol, 2.0*fs.x*NL_DAY_HORIZON_COL, fs.x*fs.x);*/
  
  vec3 horizonCol = mix(mix(NL_DAY_HORIZON_COL, NL_DAWN_HORIZON_COL, duskD(FOG_COLOR)), NL_NIGHT_HORIZON_COL, nightD(FOG_COLOR));
  
  horizonCol = mix(horizonCol, NL_RAIN_HORIZON_COL*fs.z*19.6, rainFactor);

  return horizonCol;
}

// tinting on horizon col
vec3 getHorizonEdgeCol(vec3 horizonCol, float rainFactor, vec3 FOG_COLOR) {
  float val = 2.1*(1.1-FOG_COLOR.b)*FOG_COLOR.g*(1.0-rainFactor);
  horizonCol *= vec3_splat(1.0-val) + NL_DAWN_EDGE_COL*val;

  return horizonCol;
}

// 1D sky with three color gradient
vec3 renderOverworldSky(vec3 horizonEdgeCol, vec3 horizonColor, vec3 zenithColor, vec3 viewDir) {
  float h = max(viewDir.y, 0.0);
  h = 1.0-h*h;
  float hsq = h*h;

  // gradient 1  h^16
  // gradient 2  h^8 mix h^2
  float gradient1 = hsq*hsq*hsq*hsq *hsq*hsq;
  float gradient2 = 0.6*gradient1 + 0.12*hsq;
  gradient1 *= gradient1;

  vec3 sky = mix(horizonColor, horizonEdgeCol, gradient1);
  sky = mix(zenithColor,horizonColor, gradient2);

  return sky;
}

// sunrise/sunset bloom
vec3 getSunBloom(vec3 viewDir, vec3 horizonEdgeCol, vec3 FOG_COLOR) {
  float factor = FOG_COLOR.r/length(FOG_COLOR);
  factor *= factor;
  factor *= factor;

  vec3 Pos = viewDir;
  Pos.yz *= vec2(1.5, 0.65)*0.7;

  float spread = smoothstep(0.0, 1.0, (1.0-abs(Pos.z)-abs(Pos.y)));
  float sunBloom = spread;
  sunBloom = 0.5*spread + sunBloom*sunBloom*sunBloom*1.5;

  vec3 g = mix(mix(vec3(0.0, 0.0, 0.0), vec3(1.5,0.19,0.05), sunBloom), vec3(1.0,0.16,0.05)*2.0, smoothstep(0.9, 2.0, sunBloom));

  return (g*factor*factor);
}


float enr(float a, float t, vec3 v, float ra, float tm){
  float s = sin(a*6.0 + t*tm);
  s = s*s;
  s *= 0.5 + 0.7*cos(a*ra - 1.1*t);
  return smoothstep(0.59-s, -0.7, v.y);
}

vec3 renderEndSky(vec3 horizonCol, vec3 zenithCol, vec3 viewDir, float t) {
  t *= 0.1;
  float a = atan2(viewDir.x, viewDir.z);
  vec3 v = viewDir;
  v.y = smoothstep(0.0, 2.3,abs(v.y));
  
  float g = enr(a, t, v, 4.0, 1.1);
  float g2 = enr(a, t, v, 2.0, 0.8);

  float n1 = 0.5 + 0.5*sin(3.0*a + t + 10.0*viewDir.x*viewDir.y);
  float n2 = 0.5 + 0.5*cos(5.0*a + 0.5*t + 5.0*n1 + 0.1*sin(40.0*a -4.0*t));
    
  float waves = 0.7*n2*n1 + 0.3*n1;
    
  float grad = 0.5 + 0.5*viewDir.y;
  float streaks = waves*(1.0 - grad*grad*grad);
  streaks += (1.0-streaks)*smoothstep(1.0-waves, -1.0, viewDir.y);

  float f = 0.66*streaks + 0.7*smoothstep(1.0, -0.5, viewDir.y);

  vec3 sky = mix(zenithCol, horizonCol, f*f);
  vec3 rg = (g*g*g*g*10.8)*horizonCol*0.95;
  vec3 rg2 = (g2*g2*g2*g2*7.0)*vec3(0.3,0.25,0.22)*0.95;
  sky += (rg + rg2);

  return sky;
}

vec3 nlRenderSky(vec3 horizonEdgeCol, vec3 horizonCol, vec3 zenithCol, vec3 viewDir, vec3 FOG_COLOR, float t, float rainFactor, bool end, bool underWater, bool nether) {
  vec3 sky;
  viewDir.y = -viewDir.y;

  if (end) {
    sky = renderEndSky(horizonCol, zenithCol, viewDir, t);
  } else {
    sky = renderOverworldSky(horizonEdgeCol, horizonCol, zenithCol, viewDir);
    #ifdef NL_RAINBOW
      sky += mix(NL_RAINBOW_CLEAR, NL_RAINBOW_RAIN, rainFactor)*spectrum((viewDir.z+0.6)*8.0)*max(viewDir.y, 0.0)*FOG_COLOR.g;
    #endif
    #ifdef NL_UNDERWATER_STREAKS
      if (underWater) {
        float a = atan2(viewDir.x, viewDir.z);
        float grad = 0.5 + 0.5*viewDir.y;
        grad *= grad;
        float spread = (0.5 + 0.5*cos(3.0*a + 0.2*t + 2.0*sin(5.0*a - 0.4*t)));
        spread *= (0.5 + 0.5*sin(3.0*a - sin(0.5*t)))*grad;
        spread += (1.0-spread)*grad;
        float streaks = spread*spread;
        streaks *= streaks;
        streaks = (spread + 3.0*grad*grad + 4.0*streaks*streaks);
        sky += 2.0*streaks*horizonCol;
      } else 
    #endif
    if (!nether) {
      sky += getSunBloom(viewDir, horizonEdgeCol, FOG_COLOR);
    }
  }

  return sky;
}

// sky reflection on plane
vec3 getSkyRefl(vec3 horizonEdgeCol, vec3 horizonCol, vec3 zenithCol, vec3 viewDir, vec3 FOG_COLOR, float t, float h, float rainFactor, bool end, bool underWater, bool nether) {
  viewDir.y = -viewDir.y;
  vec3 refl = nlRenderSky(horizonEdgeCol, horizonCol, zenithCol, viewDir, FOG_COLOR, t, rainFactor, end, underWater, nether);

  if (!(underWater || nether)) {
    float specular = smoothstep(0.7, 0.0, abs(viewDir.z));
    specular *= 2.0*max(FOG_COLOR.r-FOG_COLOR.b, 0.0);
    specular *= specular*viewDir.x;
    refl += horizonEdgeCol * specular * specular;
  }

  return refl;
}

// simpler sky reflection for rain
vec3 getRainSkyRefl(vec3 horizonCol, vec3 zenithCol, float h) {
  h = 1.0-h*h;
  h *= h;
  return mix(zenithCol, horizonCol, h*h);
}

#endif
