import test from 'node:test';
import assert from 'node:assert/strict';
import {
  INITIAL_INSTALL_PLAN_DRAFT,
  INITIAL_UI_TRANSIENT_STATE,
  createInstallPlanDraft,
  extractUiTransientState,
  mergeWizardState,
} from '../state/wizardState.js';

test('draft e uiState nao vazam campos um para o outro', () => {
  const draft = createInstallPlanDraft({
    ...INITIAL_INSTALL_PLAN_DRAFT,
    selectedDisks: ['/dev/sda'],
  });
  const uiState = extractUiTransientState({
    ...INITIAL_UI_TRANSIENT_STATE,
    storageBlockingIssues: ['Selecione pelo menos 1 disco fisico elegivel.'],
  });

  assert.deepEqual(draft.selectedDisks, ['/dev/sda']);
  assert.equal('storageBlockingIssues' in draft, false);
  assert.equal('storageWarnings' in draft, false);

  assert.deepEqual(uiState.storageBlockingIssues, ['Selecione pelo menos 1 disco fisico elegivel.']);
  assert.equal('selectedDisks' in uiState, false);
});

test('mergeWizardState preserva selectedDisks do draft', () => {
  const wizard = mergeWizardState(
    createInstallPlanDraft({
      ...INITIAL_INSTALL_PLAN_DRAFT,
      selectedDisks: ['/dev/sda', '/dev/sdb'],
      sysDisk: '/dev/sda',
    }),
    extractUiTransientState({
      ...INITIAL_UI_TRANSIENT_STATE,
      storageBlockingIssues: [],
      storageWarnings: [],
    }),
  );

  assert.deepEqual(wizard.selectedDisks, ['/dev/sda', '/dev/sdb']);
  assert.equal(wizard.sysDisk, '/dev/sda');
});
