#include "sem_reducao_volume.h"

#include <mmdeviceapi.h>
#include <windows.h>

// O libwebrtc abre o fone e o microfone pedindo ao Windows o "dispositivo
// padrão de comunicação" (papel eCommunications). Fluxo aberto assim conta
// como chamada, e o Windows abaixa o som dos outros programas enquanto o
// DenDen transmite ou assiste. Não há opção no libwebrtc para mudar isso,
// então o pedido é trocado aqui pelo dispositivo padrão (eConsole), o mesmo
// que jogos e players usam.
//
// A troca é feita na tabela de funções do enumerador de dispositivos, que é
// a mesma para todos os enumeradores do processo. Vale só para o DenDen.
namespace {

using GetDefaultAudioEndpointFn = HRESULT(STDMETHODCALLTYPE*)(
    IMMDeviceEnumerator*, EDataFlow, ERole, IMMDevice**);

GetDefaultAudioEndpointFn original = nullptr;

HRESULT STDMETHODCALLTYPE PadraoEmVezDeComunicacao(IMMDeviceEnumerator* self,
                                                   EDataFlow fluxo, ERole papel,
                                                   IMMDevice** dispositivo) {
  if (papel == eCommunications) papel = eConsole;
  return original(self, fluxo, papel, dispositivo);
}

}  // namespace

void InstalarSemReducaoDeVolume() {
  IMMDeviceEnumerator* enumerador = nullptr;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                              CLSCTX_ALL, IID_PPV_ARGS(&enumerador)))) {
    return;
  }
  // Posição de GetDefaultAudioEndpoint: depois dos 3 métodos de IUnknown e
  // de EnumAudioEndpoints.
  void** entrada = &(*reinterpret_cast<void***>(enumerador))[4];
  DWORD protecao = 0;
  if (VirtualProtect(entrada, sizeof(void*), PAGE_READWRITE, &protecao)) {
    original = reinterpret_cast<GetDefaultAudioEndpointFn>(*entrada);
    *entrada = reinterpret_cast<void*>(&PadraoEmVezDeComunicacao);
    VirtualProtect(entrada, sizeof(void*), protecao, &protecao);
  }
  enumerador->Release();
}
