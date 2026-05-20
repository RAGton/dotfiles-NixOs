{
  lib,
  python3Packages,
  whisper-cpp,
  piper-tts,
  alsa-utils,
  ffmpeg,
  makeWrapper,
}:

python3Packages.buildPythonApplication {
  pname = "kora";
  version = "0.1.0";
  pyproject = true;

  src = ../packages/kora;

  build-system = with python3Packages; [
    hatchling
  ];

  nativeBuildInputs = [ makeWrapper ];

  dependencies = with python3Packages; [
    fastapi
    uvicorn
    httpx
    pydantic
    python-dotenv
    pyaudio
    pyopen-wakeword
    numpy
    scipy
    edge-tts
    rich
    faster-whisper
    neo4j
    tenacity
    pyyaml
  ];

  doCheck = false;

  pythonImportsCheck = [ "kora" ];

  postInstall = ''
    for p in kora kora-api kora-admin kora-memory-worker; do
      wrapProgram $out/bin/$p \
        --prefix PATH : ${
          lib.makeBinPath [
            whisper-cpp
            piper-tts
            alsa-utils
            ffmpeg
          ]
        } \
        --set-default KORA_WHISPER_BIN "whisper-cli"
    done
  '';

  meta = {
    description = "Kora — Kryonix Personal Assistant (gateway/orchestrator)";
    platforms = lib.platforms.linux;
    license = lib.licenses.unfree;
  };
}
