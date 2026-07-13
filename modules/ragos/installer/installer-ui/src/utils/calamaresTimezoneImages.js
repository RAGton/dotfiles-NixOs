// Inspired by the Calamares installer locale module
// https://github.com/calamares/calamares
//
// Derived from the fixed timezone image list used by Calamares'
// locale/timezonewidget implementation.

export const CALAMARES_ZONE_IMAGE_KEYS = [
  '0.0', '1.0', '2.0', '3.0', '3.5', '4.0', '4.5', '5.0', '5.5', '5.75', '6.0', '6.5', '7.0',
  '8.0', '9.0', '9.5', '10.0', '10.5', '11.0', '12.0', '12.75', '13.0', '-1.0', '-2.0', '-3.0', '-3.5',
  '-4.0', '-4.5', '-5.0', '-5.5', '-6.0', '-7.0', '-8.0', '-9.0', '-9.5', '-10.0', '-11.0',
];

export const CALAMARES_IMAGE_BASE = '/imgs/calamares-timezones';
export const CALAMARES_BG_IMAGE = `${CALAMARES_IMAGE_BASE}/bg.png`;
export const CALAMARES_PIN_IMAGE = `${CALAMARES_IMAGE_BASE}/pin.png`;

export function getCalamaresZoneImagePath(zoneKey) {
  return `${CALAMARES_IMAGE_BASE}/timezone_${zoneKey}.png`;
}
