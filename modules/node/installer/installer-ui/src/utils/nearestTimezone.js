// Inspired by the Calamares installer locale module
// https://github.com/calamares/calamares
//
// This file adapts Calamares' timezone lookup ideas to a lightweight
// React/JS runtime without Qt.

import {
  CALAMARES_MAP_HEIGHT,
  CALAMARES_MAP_WIDTH,
  normalizeLongitude,
  projectTimezoneCoordinate,
  unprojectTimezoneCoordinate,
} from './timezoneProjection.js';

export function normalizeTimezoneLabel(timezone) {
  const raw = String(timezone || '').trim();
  if (!raw) return 'Timezone';
  return raw.split('/').slice(-1)[0]?.replaceAll('_', ' ') || raw;
}

export function timezoneRegionKey(timezone) {
  return String(timezone || '').split('/')[0] || 'Other';
}

export function decorateTimezoneLocation(location) {
  const latitude = Number(location?.latitude);
  const longitude = Number(location?.longitude);
  const timezone = String(location?.timezone || '').trim();

  return {
    ...location,
    timezone,
    countryCode: String(location?.countryCode || location?.country_code || '').trim().toUpperCase(),
    latitude,
    longitude,
    label: String(location?.label || '').trim() || normalizeTimezoneLabel(timezone),
    group: String(location?.group || '').trim() || timezoneRegionKey(timezone),
    region: timezoneRegionKey(timezone),
  };
}

export function isMappableTimezone(location) {
  return Number.isFinite(Number(location?.latitude)) && Number.isFinite(Number(location?.longitude));
}

export function timezoneDistanceDegrees(originLatitude, originLongitude, candidate) {
  const latitudeDifference = Math.abs(Number(candidate.latitude) - Number(originLatitude));

  const west = Math.min(normalizeLongitude(candidate.longitude), normalizeLongitude(originLongitude));
  const east = Math.max(normalizeLongitude(candidate.longitude), normalizeLongitude(originLongitude));

  let longitudeDifference = 0;
  if (west < 0 && !(east < 0)) {
    longitudeDifference = Math.min(Math.abs(west - east), Math.abs(360 + west - east));
  } else {
    longitudeDifference = Math.abs(west - east);
  }

  return latitudeDifference + longitudeDifference;
}

export function findNearestTimezoneByCoordinates(locations, latitude, longitude) {
  if (!Array.isArray(locations) || locations.length === 0) return null;

  let best = null;
  let smallestDistance = Number.POSITIVE_INFINITY;

  for (const rawLocation of locations) {
    const location = decorateTimezoneLocation(rawLocation);
    if (!isMappableTimezone(location)) continue;

    const distance = timezoneDistanceDegrees(latitude, longitude, location);
    if (distance < smallestDistance) {
      best = location;
      smallestDistance = distance;
    }
  }

  return best;
}

export function findNearestTimezoneByMapPoint(
  x,
  y,
  locations,
  width = CALAMARES_MAP_WIDTH,
  height = CALAMARES_MAP_HEIGHT,
) {
  if (!Array.isArray(locations) || locations.length === 0) {
    return { match: null, coordinates: null };
  }

  const coordinates = unprojectTimezoneCoordinate(x, y, width, height);

  let best = null;
  let smallestScore = Number.POSITIVE_INFINITY;

  for (const rawLocation of locations) {
    const location = decorateTimezoneLocation(rawLocation);
    if (!isMappableTimezone(location)) continue;

    const projected = projectTimezoneCoordinate(location.longitude, location.latitude, width, height);
    const pixelDistance = Math.hypot(projected.x - x, projected.y - y);
    const geoDistance = timezoneDistanceDegrees(coordinates.latitude, coordinates.longitude, location);
    const score = geoDistance + (pixelDistance / Math.max(width, height));

    if (score < smallestScore) {
      smallestScore = score;
      best = {
        ...location,
        ...projected,
      };
    }
  }

  return { match: best, coordinates };
}
