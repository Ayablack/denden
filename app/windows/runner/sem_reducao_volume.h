#ifndef RUNNER_SEM_REDUCAO_VOLUME_H_
#define RUNNER_SEM_REDUCAO_VOLUME_H_

// Faz o áudio do DenDen não contar como chamada para o Windows, que então
// não abaixa o volume dos outros programas.
void InstalarSemReducaoDeVolume();

#endif  // RUNNER_SEM_REDUCAO_VOLUME_H_
