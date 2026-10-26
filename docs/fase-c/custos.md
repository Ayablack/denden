# Relatório de Custos (Estimativa)

Este documento apresenta as estimativas de custos de transmissão do DenDen, com base nos perfis de qualidade do aplicativo e na configuração de infraestrutura do backend.

## 1. Perfis de Qualidade e Consumo

O consumo de dados de uma transmissão depende do perfil de qualidade de vídeo escolhido e de quantos espectadores estão assistindo simultaneamente. A tabela abaixo detalha o consumo estimado em **GB por hora**:

| Perfil de Qualidade | 1 Espectador | 2 Espectadores | 3 Espectadores | 4 Espectadores | 5 Espectadores |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Alta (1080p60)** | 2,7 GB/h | 5,4 GB/h | 8,1 GB/h | 10,8 GB/h | 13,5 GB/h |
| **Média (720p60)** | 1,575 GB/h | 3,15 GB/h | 4,725 GB/h | 6,3 GB/h | 7,875 GB/h |
| **Economia (720p30)** | 0,9 GB/h | 1,8 GB/h | 2,7 GB/h | 3,6 GB/h | 4,5 GB/h |

**Como a conta é feita:**
O cálculo converte o *bitrate* máximo (em bits por segundo) para Gigabytes por hora (GB/h).
Fórmula: `(Bitrate bps × 3600 segundos) / 8 / 1.000.000.000 × (número de espectadores)`
*Exemplo (Alta, 1 espectador):* `(6.000.000 × 3600) / 8 / 1.000.000.000 = 2,7 GB/h`.

## 2. Horas de Transmissão no Orçamento (900 GB)

O sistema possui um orçamento preventivo configurado de **900 GB** por mês. Veja quantas horas mensais de transmissão podem ser feitas, sem ultrapassar esse orçamento de 900 GB, dependendo do público simultâneo:

| Perfil de Qualidade | Limite de Horas (1 Espectador) | Limite de Horas (5 Espectadores) |
| :--- | :---: | :---: |
| **Alta (1080p60)** | ~ 333 horas | ~ 66 horas |
| **Média (720p60)** | ~ 571 horas | ~ 114 horas |
| **Economia (720p30)** | 1000 horas | 200 horas |

**Como a conta é feita:**
Fórmula: `900 GB / Consumo do Perfil`
*Exemplo (Alta, 1 espectador):* `900 / 2,7 = 333,33 horas`.

## 3. Custos ao Ultrapassar a Franquia

O provedor oferece uma franquia gratuita de **1000 GB por mês**. O tráfego excedente custa **US$ 0,05 por GB**.

**Exemplo de cálculo fora da franquia:**
Imagine que em um determinado mês o consumo total atinja **1200 GB**. A conta será feita da seguinte forma:
1. **Total consumido:** 1200 GB
2. **Desconto da franquia:** 1200 GB - 1000 GB (gratuitos) = 200 GB excedentes.
3. **Cálculo do custo:** 200 GB × US$ 0,05 = **US$ 10,00**.

> **⚠️ AVISO IMPORTANTE**
>
> 1. Os valores de tráfego apresentados neste relatório são **estimativas matemáticas** baseadas nos bitrates máximos da aplicação. O consumo real da rede pode variar.
> 2. O **bloqueio automático do DenDen** ao atingir o limite (budget de 900 GB e teto de 105%) **NÃO é um limite de faturamento garantido**. Ele é uma medida de mitigação de esforço razoável (*best-effort*) contra gastos imprevistos, mas devido a atrasos de rede ou de contabilidade, é possível que o consumo real passe da estimativa antes da transmissão ser derrubada, incorrendo em cobranças reais por parte do provedor.
