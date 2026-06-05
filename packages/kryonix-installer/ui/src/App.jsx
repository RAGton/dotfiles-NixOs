import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Layout from './components/Layout.jsx';
import FooterFixed from './components/FooterFixed.jsx';
import Welcome from './pages/Welcome.jsx';
import Eula from './pages/Eula.jsx';
import Localization from './pages/Localization.jsx';
import Timezone from './pages/Timezone.jsx';
import Network from './pages/Network.jsx';
import Disks from './pages/Disks.jsx';
import Users from './pages/Users.jsx';
import Summary from './pages/Summary.jsx';
import Install from './pages/Install.jsx';
import { validateStep } from './utils/installPlan.js';
import {
  createInstallPlanDraft,
  extractUiTransientState,
  INITIAL_INSTALL_PLAN_DRAFT,
  INITIAL_UI_TRANSIENT_STATE,
  mergeWizardState,
  readStoredWizardState,
  splitWizardPatch,
  writeStoredWizardState,
} from './state/wizardState.js';

const STEPS = [
  {
    id: 'welcome',
    title: 'Kryonix Installer',
    subtitle: 'Fluxo imersivo, fullscreen, sem rolagem global e com foco em robustez operacional.',
  },
  {
    id: 'eula',
    title: 'EULA e Avisos',
    subtitle: 'Aceite explícito antes de qualquer ação destrutiva ou configuração do sistema.',
  },
  {
    id: 'localization',
    title: 'Localização',
    subtitle: 'Todos os países, idiomas/locales e keymaps em listas pesquisáveis, como installers completos.',
  },
  {
    id: 'timezone',
    title: 'Fuso Horário',
    subtitle: '',
  },
  {
    id: 'network',
    title: 'Topologia de Rede',
    subtitle: 'WAN, LAN, hostname e parâmetros essenciais do servidor sem navegação ambígua.',
  },
  {
    id: 'disks',
    title: 'Particionamento',
    subtitle: 'Visualização técnica de discos com validação alinhada ao contrato canônico.',
  },
  {
    id: 'users',
    title: 'Usuário e SSH',
    subtitle: 'Conta administrativa, senha forte e chaves SSH autorizadas.',
  },
  {
    id: 'summary',
    title: 'Resumo final',
    subtitle: 'Revisão final antes de gerar o plano e iniciar a instalação.',
  },
  {
    id: 'install',
    title: 'Instalação',
    subtitle: 'Execução em tempo real com status, logs e resultado final.',
  },
];

function getInitialWizardState() {
  const stored = readStoredWizardState();

  return {
    stepIndex: Math.max(0, Math.min(stored?.stepIndex ?? 0, STEPS.length - 1)),
    draft: stored?.draft ?? createInstallPlanDraft(INITIAL_INSTALL_PLAN_DRAFT),
    uiState: stored?.uiState ?? extractUiTransientState(INITIAL_UI_TRANSIENT_STATE),
  };
}

export default function App() {
  const initialState = useMemo(() => getInitialWizardState(), []);
  const [stepIndex, setStepIndex] = useState(initialState.stepIndex);
  const [wizardState, setWizardState] = useState({
    draft: initialState.draft,
    uiState: initialState.uiState,
  });

  const draft = wizardState.draft;
  const uiState = wizardState.uiState;
  const wizard = useMemo(() => mergeWizardState(draft, uiState), [draft, uiState]);
  const step = STEPS[stepIndex];
  const eulaLocked = step.id === 'eula';
  const progressValue = STEPS.length > 1
    ? Math.round((stepIndex / (STEPS.length - 1)) * 100)
    : 100;

  const currentValidation = useMemo(
    () => validateStep(step.id, draft, uiState),
    [draft, step.id, uiState],
  );

  const footerIssues = currentValidation.blockingIssues.length > 0
    ? currentValidation.blockingIssues
    : currentValidation.warnings;
  const canGoNext = currentValidation.blockingIssues.length === 0;

  useEffect(() => {
    writeStoredWizardState({ stepIndex, draft, uiState });
  }, [draft, stepIndex, uiState]);

  const updateWizard = useCallback((patchOrUpdater) => {
    setWizardState((previous) => {
      const previousView = mergeWizardState(previous.draft, previous.uiState);
      const nextPatch = typeof patchOrUpdater === 'function'
        ? patchOrUpdater(previousView)
        : patchOrUpdater;

      const { draftPatch, uiPatch } = splitWizardPatch(nextPatch);

      return {
        draft: Object.keys(draftPatch).length > 0
          ? createInstallPlanDraft({ ...previous.draft, ...draftPatch })
          : previous.draft,
        uiState: Object.keys(uiPatch).length > 0
          ? extractUiTransientState({ ...previous.uiState, ...uiPatch })
          : previous.uiState,
      };
    });
  }, []);

  const goNext = useCallback(
    () => setStepIndex((previous) => Math.min(STEPS.length - 1, previous + 1)),
    [],
  );
  const goBack = useCallback(
    () => setStepIndex((previous) => Math.max(0, previous - 1)),
    [],
  );

  // Navegação por teclado (Gate 6 — keyboard-only). Atalhos de "Próximo":
  // Enter (fora de campos), Alt+N, Alt+→, Ctrl+Enter. "Voltar": Alt+B, Alt+←, Alt+Backspace.
  // Esc é no-op: nunca sai do kiosk nem fecha o Chromium.
  useEffect(() => {
    const onKeyDown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        return;
      }
      // F1 (Ajuda) / F2 (Logs): reservados — impede a ajuda nativa do Chromium.
      // (overlays de ajuda/logs entram numa próxima iteração da Fase 0.2)
      if (event.key === 'F1' || event.key === 'F2') {
        event.preventDefault();
        return;
      }

      const tag = event.target?.tagName;
      const isTyping =
        tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || event.target?.isContentEditable;

      const k = event.key;
      const explicitNext =
        (event.altKey && (k === 'n' || k === 'N' || k === 'ArrowRight')) ||
        (event.ctrlKey && k === 'Enter');
      const bareEnterNext = k === 'Enter' && !isTyping && !event.altKey && !event.ctrlKey;
      const wantBack =
        event.altKey && (k === 'b' || k === 'B' || k === 'ArrowLeft' || k === 'Backspace');

      // EULA: Enter "pelado" NÃO avança (evita aceite acidental); só atalho explícito
      // e somente após o aceite (canGoNext). O Space no checkbox continua nativo.
      if (step.id === 'eula') {
        if (k === 'Enter' && !isTyping) event.preventDefault();
        if (explicitNext && canGoNext) {
          event.preventDefault();
          goNext();
        }
        return;
      }

      if (wantBack) {
        event.preventDefault();
        goBack();
        return;
      }
      if ((explicitNext || bareEnterNext) && canGoNext) {
        event.preventDefault();
        goNext();
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [canGoNext, step.id, goNext, goBack]);

  // Foco inicial previsível: ao trocar de etapa, foca o primeiro elemento
  // interativo da página (EULA → checkbox, Disks → primeiro card, Users → 1º campo).
  const pageRef = useRef(null);
  useEffect(() => {
    const root = pageRef.current;
    if (!root) return;
    const sel =
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [role="button"]:not([aria-disabled="true"]), [tabindex]:not([tabindex="-1"])';
    const el = root.querySelector(sel);
    if (el && typeof el.focus === 'function') {
      // requestAnimationFrame: garante que a etapa já montou antes de focar
      requestAnimationFrame(() => el.focus());
    }
  }, [stepIndex]);

  const stepsWithState = useMemo(
    () => STEPS.map((item, index) => ({
      ...item,
      status: index < stepIndex ? 'done' : index === stepIndex ? 'current' : 'upcoming',
    })),
    [stepIndex],
  );

  const pageProps = {
    draft,
    uiState,
    wizard,
    onChange: updateWizard,
    validation: currentValidation,
  };

  const currentPage = (() => {
    switch (step.id) {
      case 'welcome':
        return <Welcome />;
      case 'eula':
        return <Eula {...pageProps} />;
      case 'localization':
        return <Localization {...pageProps} />;
      case 'timezone':
        return <Timezone {...pageProps} />;
      case 'network':
        return <Network {...pageProps} />;
      case 'disks':
        return <Disks {...pageProps} />;
      case 'users':
        return <Users {...pageProps} />;
      case 'summary':
        return <Summary {...pageProps} />;
      case 'install':
        return <Install {...pageProps} />;
      default:
        return null;
    }
  })();

  return (
    <Layout
      title={step.title}
      subtitle={step.subtitle}
      stepLabel={`Etapa ${stepIndex + 1} de ${STEPS.length}`}
      steps={stepsWithState}
      currentStepIndex={stepIndex}
      navigationHint={eulaLocked ? 'Atalhos bloqueados na EULA' : 'Alt + ← / Alt + →'}
      onStepJump={(index) => {
        if (step.id === 'eula') return;
        if (index <= stepIndex || index === stepIndex + 1) {
          setStepIndex(index);
        }
      }}
      footer={(
        <FooterFixed
          progressLabel={`${step.title} • ${progressValue}%`}
          progressValue={progressValue}
          issues={footerIssues}
          canBack={stepIndex > 0}
          canNext={step.id === 'install' ? false : canGoNext}
          onBack={() => setStepIndex((previous) => Math.max(0, previous - 1))}
          onNext={() => setStepIndex((previous) => Math.min(STEPS.length - 1, previous + 1))}
          hintText={step.id === 'eula'
            ? 'Nesta etapa, o avanço só é permitido pelo botão Próximo após marcar o aceite.'
            : 'Pronto para avançar. Navegação rápida: Alt + ← / Alt + →'}
          nextLabel={step.id === 'summary' ? 'Ir para instalação' : step.id === 'install' ? 'Em execução' : 'Próximo'}
        />
      )}
    >
      <div className="wizard-page" ref={pageRef} style={{ display: 'contents' }}>
        {currentPage}
      </div>
    </Layout>
  );
}
