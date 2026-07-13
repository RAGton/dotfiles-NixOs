import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  applyExecutionStatus,
  appendInstallLog,
  createInitialExecutionState,
  createInstallLog,
  hydrateExecutionState,
  INSTALL_EXECUTION_PHASES,
} from '../utils/installExecution.js';
import { installerApi, getInstallerApiErrorMessage } from '../utils/installerApi.js';
import {
  buildInstallPlanPayload,
  buildInstallSecretsPayload,
  validateInstallPlanPayload,
  validateStep,
} from '../utils/installPlan.js';

export function useInstallExecution({ draft, uiState }) {
  const [executionState, setExecutionState] = useState(() => createInitialExecutionState());
  const reconnectTimerRef = useRef(null);
  const closeStreamRef = useRef(null);

  const planPayload = useMemo(() => buildInstallPlanPayload(draft), [draft]);
  const secretsPayload = useMemo(() => buildInstallSecretsPayload(draft), [draft]);
  const installValidation = useMemo(
    () => validateStep('install', draft, uiState),
    [draft, uiState],
  );

  const clearReconnectTimer = useCallback(() => {
    if (reconnectTimerRef.current) {
      window.clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);

  const closeStream = useCallback(() => {
    clearReconnectTimer();
    closeStreamRef.current?.();
    closeStreamRef.current = null;
  }, [clearReconnectTimer]);

  const hydrateFromBackend = useCallback(async () => {
    const [statusPayload, logPayload] = await Promise.all([
      installerApi.getStatus(),
      installerApi.getLog().catch(() => ({ tail: '' })),
    ]);

    setExecutionState(hydrateExecutionState(statusPayload, logPayload?.tail || ''));
    return statusPayload;
  }, []);

  const connectStream = useCallback(() => {
    closeStream();

    closeStreamRef.current = installerApi.openInstallLogStream({
      onLog(chunk) {
        setExecutionState((previous) => ({
          ...previous,
          logTail: appendInstallLog(previous.logTail, chunk),
          streamConnected: true,
        }));
      },
      onStatus(statusPayload) {
        setExecutionState((previous) => applyExecutionStatus(previous, statusPayload, { streamConnected: true }));
      },
      onDone(exitCode) {
        closeStream();
        setExecutionState((previous) => applyExecutionStatus(previous, {
          ...previous.status,
          running: false,
          exitCode,
          havePlan: previous.status.havePlan,
        }, { streamConnected: false }));
      },
      async onError() {
        closeStream();
        try {
          const statusPayload = await installerApi.getStatus();
          setExecutionState((previous) => applyExecutionStatus(previous, statusPayload, { streamConnected: false }));

          if (statusPayload?.running) {
            reconnectTimerRef.current = window.setTimeout(() => {
              connectStream();
            }, 1000);
          }
        } catch (error) {
          setExecutionState((previous) => ({
            ...previous,
            streamConnected: false,
            globalError: getInstallerApiErrorMessage(error, 'Falha ao reconectar aos logs da instalacao.'),
          }));
        }
      },
    });

    setExecutionState((previous) => ({
      ...previous,
      streamConnected: true,
    }));
  }, [closeStream]);

  useEffect(() => {
    let cancelled = false;

    async function hydrate() {
      try {
        const statusPayload = await hydrateFromBackend();
        if (!cancelled && statusPayload?.running) {
          connectStream();
        }
      } catch (error) {
        if (!cancelled) {
          setExecutionState((previous) => ({
            ...previous,
            globalError: getInstallerApiErrorMessage(error, 'Falha ao reidratar o estado da instalacao.'),
          }));
        }
      }
    }

    hydrate();

    return () => {
      cancelled = true;
      closeStream();
    };
  }, [closeStream, connectStream, hydrateFromBackend]);

  const startInstallation = useCallback(async () => {
    if (!uiState.destructiveConfirmed) {
      setExecutionState((previous) => ({
        ...previous,
        globalError: 'Confirme o wipe de discos antes de iniciar.',
      }));
      return false;
    }

    if (installValidation.blockingIssues.length > 0) {
      setExecutionState((previous) => ({
        ...previous,
        globalError: installValidation.blockingIssues[0],
      }));
      return false;
    }

    try {
      validateInstallPlanPayload(planPayload);
      closeStream();
      setExecutionState((previous) => ({
        ...previous,
        phase: INSTALL_EXECUTION_PHASES.VALIDATING,
        globalError: '',
        logTail: createInstallLog('[INPUT] Validando payload final antes de salvar o plano...\n'),
        streamConnected: false,
      }));

      await installerApi.savePlan(planPayload, secretsPayload);

      setExecutionState((previous) => ({
        ...previous,
        planSubmitted: true,
      }));

      await installerApi.startInstall(true);

      setExecutionState((previous) => applyExecutionStatus(previous, {
        ...previous.status,
        havePlan: true,
        running: true,
        exitCode: null,
        currentPhase: 'INPUT',
      }, { streamConnected: true }));

      setExecutionState((previous) => ({
        ...previous,
        logTail: appendInstallLog(previous.logTail, '[INPUT] Execucao iniciada. Streaming de logs conectado...\n'),
      }));

      connectStream();
      return true;
    } catch (error) {
      setExecutionState((previous) => ({
        ...previous,
        phase: INSTALL_EXECUTION_PHASES.FAILED,
        globalError: getInstallerApiErrorMessage(error, 'Erro ao iniciar a instalacao.'),
        streamConnected: false,
      }));
      return false;
    }
  }, [
    closeStream,
    connectStream,
    installValidation.blockingIssues,
    planPayload,
    secretsPayload,
    uiState.destructiveConfirmed,
  ]);

  const requestReboot = useCallback(async () => {
    try {
      setExecutionState((previous) => ({
        ...previous,
        globalError: '',
      }));

      await installerApi.reboot();

      setExecutionState((previous) => ({
        ...previous,
        logTail: appendInstallLog(previous.logTail, '\n[VERIFY] Reinicio solicitado ao sistema...\n'),
      }));

      return true;
    } catch (error) {
      setExecutionState((previous) => ({
        ...previous,
        globalError: getInstallerApiErrorMessage(error, 'Erro ao reiniciar o sistema.'),
      }));
      return false;
    }
  }, []);

  return {
    executionState,
    planPayload,
    secretsPayload,
    installValidation,
    startInstallation,
    requestReboot,
    refreshExecution: hydrateFromBackend,
  };
}
