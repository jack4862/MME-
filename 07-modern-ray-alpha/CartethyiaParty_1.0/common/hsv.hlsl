float3 rgb_to_hsv(float3 rgb)
{
  float h, s, v;

  float cmax = max(rgb[0], max(rgb[1], rgb[2]));
  float cmin = min(rgb[0], min(rgb[1], rgb[2]));
  float cdelta = cmax - cmin;

  v = cmax;
  if (cmax != 0.0) {
    s = cdelta / cmax;
  }
  else {
    s = 0.0;
    h = 0.0;
  }

  if (s == 0.0) {
    h = 0.0;
  }
  else {
    float3 c = (cmax - rgb) / cdelta;

    if (rgb.x == cmax) {
      h = c[2] - c[1];
    }
    else if (rgb.y == cmax) {
      h = 2.0 + c[0] - c[2];
    }
    else {
      h = 4.0 + c[1] - c[0];
    }

    h /= 6.0;

    if (h < 0.0) {
      h += 1.0;
    }
  }

  return float3(h, s, v);
}

float3 hsv_to_rgb(float3 hsv)
{
  float i, f, p, q, t, h, s, v;
  float3 rgb;

  h = hsv[0];
  s = hsv[1];
  v = hsv[2];

  if (s == 0.0) {
    rgb = v;
  }
  else {
    if (h == 1.0) {
      h = 0.0;
    }

    h *= 6.0;
    i = floor(h);
    f = h - i;
    rgb = f;
    p = v * (1.0 - s);
    q = v * (1.0 - (s * f));
    t = v * (1.0 - (s * (1.0 - f)));

    if (i == 0.0) {
      rgb = float3(v, t, p);
    }
    else if (i == 1.0) {
      rgb = float3(q, v, p);
    }
    else if (i == 2.0) {
      rgb = float3(p, v, t);
    }
    else if (i == 3.0) {
      rgb = float3(p, q, v);
    }
    else if (i == 4.0) {
      rgb = float3(t, p, v);
    }
    else {
      rgb = float3(v, p, q);
    }
  }

  return rgb;
}

float3 hue_sat_value(float3 col, float hue, float sat, float value, float fac = 1)
{
  float3 hsv = rgb_to_hsv(col);

  hsv[0] = frac(hsv[0] + hue + 0.5);
  hsv[1] = clamp(hsv[1] * sat, 0.0, 1.0);
  hsv[2] = hsv[2] * value;

  float3 rgb = hsv_to_rgb(hsv);

  return lerp(col, rgb, fac);
}