import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildRaidPlanSummary,
  buildSplitPlanSummary,
  getRaidOptionsForSelection,
  getStorageRecommendation,
  validateRaidSelection,
  validateSingleDiskLayout,
  validateSingleProfileSelection,
  validateSplitDiskLayout,
} from '../utils/storagePlanner.js';

const GiB = 1024 ** 3;

function createDisk(path, sizeBytes) {
  return {
    path,
    name: path.split('/').pop(),
    type: 'disk',
    sizeBytes,
    model: 'TestDisk',
    readOnly: false,
    removable: false,
    hotplug: false,
    transport: 'virtio',
  };
}

test('raid options respect minimum member count and parity rules', () => {
  const disks = [
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 100 * GiB),
    createDisk('/dev/sdc', 100 * GiB),
  ];

  const options = getRaidOptionsForSelection(disks);

  assert.equal(options.find((item) => item.id === 'raid0')?.enabled, true);
  assert.equal(options.find((item) => item.id === 'raid1')?.enabled, true);
  assert.equal(options.find((item) => item.id === 'raid5')?.enabled, true);
  assert.equal(options.find((item) => item.id === 'raid10')?.enabled, false);
  assert.match(options.find((item) => item.id === 'raid10')?.blockingReasons[0] || '', /quantidade par|minimo/i);
});

test('conservative validation blocks heterogeneous raid1/5/10 but still allows raid0', () => {
  const disks = [
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 100 * GiB),
    createDisk('/dev/sdc', 80 * GiB),
  ];

  assert.equal(validateRaidSelection(disks, 'raid0').valid, true);
  assert.equal(validateRaidSelection(disks, 'raid1').valid, false);
  assert.equal(validateRaidSelection(disks, 'raid5').valid, false);
});

test('raid summary calculates usable capacity conservatively', () => {
  const disks = [
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 100 * GiB),
    createDisk('/dev/sdc', 100 * GiB),
    createDisk('/dev/sdd', 100 * GiB),
  ];

  const raid10 = buildRaidPlanSummary(disks, 'raid10');
  const raid5 = buildRaidPlanSummary(disks, 'raid5');

  assert.equal(raid10.usableBytes, 200 * GiB);
  assert.equal(raid5.usableBytes, 300 * GiB);
  assert.equal(raid10.faultTolerance.includes('espelho'), true);
});

test('single profile rejects more than two selected disks', () => {
  const disks = [
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 100 * GiB),
    createDisk('/dev/sdc', 100 * GiB),
  ];

  const validation = validateSingleProfileSelection(disks);
  assert.equal(validation.valid, false);
  assert.match(validation.blockingReasons[0], /maximo 2 discos/i);
});

test('single disk layout accepts one root disk and split requires roles distintos', () => {
  const disks = [
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 200 * GiB),
  ];

  assert.equal(validateSingleDiskLayout(disks, '/dev/sda').valid, true);
  assert.equal(validateSplitDiskLayout(disks, '/dev/sda', '/dev/sdb').valid, true);
  assert.equal(validateSplitDiskLayout(disks, '/dev/sda', '/dev/sda').valid, false);
});

test('split summary reports explicit system and data disks', () => {
  const disks = [
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 200 * GiB),
  ];

  const summary = buildSplitPlanSummary(disks, '/dev/sda', '/dev/sdb');
  assert.equal(summary.systemDisk, '/dev/sda');
  assert.equal(summary.dataDisk, '/dev/sdb');
  assert.equal(summary.rawBytes, 300 * GiB);
});

test('storage recommendation prefers safe redundant profiles', () => {
  const raid10Recommendation = getStorageRecommendation([
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 100 * GiB),
    createDisk('/dev/sdc', 100 * GiB),
    createDisk('/dev/sdd', 100 * GiB),
  ]);
  assert.equal(raid10Recommendation.profile, 'raid');
  assert.equal(raid10Recommendation.raidLevel, 'raid10');

  const conservativeFallback = getStorageRecommendation([
    createDisk('/dev/sda', 100 * GiB),
    createDisk('/dev/sdb', 60 * GiB),
  ]);
  assert.equal(conservativeFallback.profile, 'single');
});
