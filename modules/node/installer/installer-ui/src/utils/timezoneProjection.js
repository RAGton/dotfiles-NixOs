// Inspired by the Calamares installer locale module
// https://github.com/calamares/calamares
//
// The projection below adapts the heuristics from Calamares'
// TimeZoneImageList::getLocationPosition() to a React/JS environment.

export const CALAMARES_MAP_WIDTH = 780;
export const CALAMARES_MAP_HEIGHT = 340;

const MAP_Y_OFFSET = 0.125;
const MAP_X_OFFSET = -0.037;

export function normalizeLongitude(longitude) {
  let value = Number(longitude);
  if (!Number.isFinite(value)) return 0;

  while (value < -180) value += 360;
  while (value > 180) value -= 360;
  return value;
}

export function clampLatitude(latitude) {
  const value = Number(latitude);
  if (!Number.isFinite(value)) return 0;
  return Math.max(-90, Math.min(90, value));
}

function applyPolarCorrections(y, latitude, height) {
  let nextY = y;

  if (latitude > 70.0) {
    nextY -= Math.sin(Math.PI * (latitude - 70.0) / 56.0) * MAP_Y_OFFSET * height * 0.8;
  }
  if (latitude > 74.0) {
    nextY += 4;
  }
  if (latitude > 69.0) {
    nextY -= 2;
  }
  if (latitude > 59.0) {
    nextY -= 4 * Math.trunc((latitude - 54.0) / 5.0);
  }
  if (latitude > 54.0) {
    nextY -= 2;
  }
  if (latitude > 49.0) {
    nextY -= Math.trunc((latitude - 44.0) / 5.0);
  }
  if (latitude < 0) {
    nextY += Math.trunc((-latitude) / 5.0);
  }
  if (latitude < -60) {
    nextY = height - 1;
  }

  return nextY;
}

export function projectTimezoneCoordinate(
  longitude,
  latitude,
  width = CALAMARES_MAP_WIDTH,
  height = CALAMARES_MAP_HEIGHT,
) {
  const safeLongitude = normalizeLongitude(longitude);
  const safeLatitude = clampLatitude(latitude);

  let x = (width / 2 + ((width / 2) * safeLongitude) / 180.0) + (MAP_X_OFFSET * width);
  let y = (height / 2 - ((height / 2) * safeLatitude) / 90.0) + (MAP_Y_OFFSET * height);

  y = applyPolarCorrections(y, safeLatitude, height);

  if (x < 0) x = width + x;
  if (x >= width) x -= width;
  if (y < 0) y = height + y;
  if (y >= height) y -= height;

  return {
    x,
    y,
    xPct: (x / width) * 100,
    yPct: (y / height) * 100,
    longitude: safeLongitude,
    latitude: safeLatitude,
  };
}

export function unprojectTimezoneCoordinate(
  x,
  y,
  width = CALAMARES_MAP_WIDTH,
  height = CALAMARES_MAP_HEIGHT,
) {
  const safeX = Math.max(0, Math.min(width, Number(x) || 0));
  const safeY = Math.max(0, Math.min(height, Number(y) || 0));

  const longitude = normalizeLongitude((((safeX - (MAP_X_OFFSET * width)) - (width / 2)) / (width / 2)) * 180);
  const latitude = clampLatitude(-((((safeY - (MAP_Y_OFFSET * height)) - (height / 2)) / (height / 2)) * 90));

  return { longitude, latitude };
}
