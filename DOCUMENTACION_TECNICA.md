# 4ssiz - Granular Synth
## Trabajo Final - Teoría del Audio Digital
### Universidad Nacional de las Artes

---

## 1. DESCRIPCIÓN DEL PROYECTO

Este proyecto implementa un **sintetizador granular** utilizando SuperCollider, aplicando los conceptos teóricos de la **Unidad 2: Técnicas de síntesis y procesamiento** del programa de Teoría del Audio Digital.

### 1.1 Modalidad Elegida
**Opción 2: Implementación y Documentación de un Sintetizador Híbrido**

---

## 2. FUNDAMENTOS TEÓRICOS

### 2.1 Síntesis Granular
La síntesis granular es una técnica de síntesis que opera sobre **granos** (pequeños fragmentos de sonido de 10-100ms de duración). Cada grano es procesado individualmente y luego recombinado para crear texturas sonoras complejas.

### 2.2 Implementación Técnica
- **Algoritmo principal**: `GrainBuf.ar` de SuperCollider
- **Modulación de posición**: LFO (`LFNoise1.kr`) para controlar dónde se lee en el buffer
- **Panning aleatorio**: Distribución espacial del sonido
- **Control de gate**: Envelope ASR para manejo de la síntesis

---

## 3. ARQUITECTURA DEL SISTEMA

### 3.1 SynthDef Principal
```supercollider
SynthDef(\granularLoFi, {
    |buf = 0, grainRate = 20, grainDur = 0.1, posFreq = 5, gain = 0.3, gate = 1|
    var pos, sig, pan, env;
    
    // Envelope para control de gate
    env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
    
    // Posición aleatoria en el buffer controlada por LFO
    pos = LFNoise1.kr(posFreq).range(0, BufFrames.kr(buf));
    
    // Síntesis granular
    sig = GrainBuf.ar(
        numChannels: 1,
        trigger: Impulse.kr(grainRate),
        dur: grainDur,
        sndbuf: buf,
        rate: 1,
        pos: pos / BufFrames.kr(buf),
        interp: 2
    );

    // Envío de triggers para visualización
    SendTrig.kr(Impulse.kr(grainRate), 0, grainDur);
    
    // Panning aleatorio
    pan = LFNoise1.kr(1).range(-1, 1);
    sig = Pan2.ar(sig * gain * env, pan);

    Out.ar(0, sig);
}).add;
```

### 3.2 Sistema de Visualización
- **OSCdef**: Recibe triggers del sintetizador para visualizar granos
- **UserView**: Canvas para dibujar granos en tiempo real
- **Actualización automática**: Task que refresca la visualización cada 50ms

### 3.3 Interfaz de Usuario
- **GUI unificada**: Controles y visualización en una sola ventana
- **Controles en tiempo real**: Rate, Duración, LFO, Volumen
- **Selector de archivos**: Carga de samples integrada
- **Botones de control**: Play/Stop toggle, Clear

---

## 4. PARÁMETROS DE CONTROL

### 4.1 Parámetros Principales
- **Rate (1-100 Hz)**: Velocidad de generación de granos
- **Duración (0.01-0.5s)**: Duración de cada grano individual
- **LFO Pos (0.1-20 Hz)**: Frecuencia del LFO que controla la posición en el buffer
- **Volumen (0-1)**: Nivel de salida del sintetizador

### 4.2 Parámetros Internos
- **Interpolación**: Interpolación cúbica (valor 2) para suavizar transiciones
- **Panning**: Distribución aleatoria en el campo estéreo
- **Gate**: Control de encendido/apagado del sintetizador

---

## 5. ASPECTOS TÉCNICOS RELEVANTES

### 5.1 Teorema de Muestreo
El sintetizador respeta el teorema de Nyquist-Shannon al trabajar con buffers de audio muestreados correctamente.

### 5.2 Cuantización y Dithering
- **Interpolación cúbica**: Reduce artefactos de cuantización en la lectura del buffer
- **Modulación suave**: LFO de baja frecuencia evita discontinuidades

### 5.3 Protocolos de Control
- **OSC (Open Sound Control)**: Para comunicación entre síntesis y visualización
- **Triggers**: Sistema de mensajes para sincronización temporal

---

## 6. IMPLEMENTACIÓN PRÁCTICA

### 6.1 Flujo de Trabajo
1. **Inicialización**: Carga del servidor y registro del SynthDef
2. **Carga de sample**: Selección y carga de archivo de audio
3. **Síntesis**: Generación de granos con parámetros ajustables
4. **Visualización**: Representación gráfica en tiempo real
5. **Control**: Modificación de parámetros en tiempo real

### 6.2 Gestión de Memoria
- **Buffers**: Liberación automática al cambiar samples
- **Granos**: Limpieza automática de granos antiguos
- **Ventanas**: Cierre correcto de recursos al salir

---

## 7. POSIBILIDADES EXPRESIVAS

### 7.1 Texturas Sonoras
- **Granulación densa**: Rate alto + duración corta
- **Texturas ambientales**: Rate bajo + duración larga
- **Efectos de glitch**: Modulación rápida del LFO

### 7.2 Control Espacial
- **Panning aleatorio**: Distribución dinámica en el campo estéreo
- **Densidad variable**: Control de la cantidad de granos simultáneos

---

## 8. CONCLUSIONES

Este sintetizador granular demuestra la aplicación práctica de los conceptos teóricos de síntesis de sonido, específicamente:

- **Síntesis granular**: Implementación directa de la técnica
- **Modulación**: Uso de LFOs para control de parámetros
- **Procesamiento de señales**: Manipulación de buffers de audio
- **Interfaz humano-máquina**: Control en tiempo real

El proyecto cumple con los objetivos de la **Opción 2** al implementar una técnica de síntesis específica, documentar exhaustivamente el código, y proporcionar una herramienta funcional para la creación musical.

---

## 9. BIBLIOGRAFÍA

- Roads, Curtis (1995): *The Computer Music Tutorial*, MIT Press
- Di Liscia, O. P. (2004): *Síntesis y Procesamiento de Sonido y Música a través del programa Csound*, UNQ
- Moore, F.R. (1990): *Elements of Computer Music*, Prentice Hall
- Documentación oficial de SuperCollider: https://supercollider.github.io/

---

*Documentación técnica generada para el Trabajo Final de Teoría del Audio Digital - UNA*
