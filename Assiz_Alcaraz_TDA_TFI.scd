// ===============================================
// Assiz Alcaraz - Granular Synth
// Trabajo Final Integrador - Teoría del Audio Digital
// Universidad Nacional de las Artes - Año 2025
// ===============================================

// Inicializar servidor
s.boot;

// Variables globales
~grainRate = 20; // Tasa de granos moderada
~grainDur = 0.3; // Duración fija de granos
~grainPosFreq = 5;
~gain = 0.3;
~grainCount = 8;  // Máximo de granos simultáneos
~maxGrains = 300;  // Máximo de granos simultáneos (activos al mismo tiempo)
~pitchVariation = 0.3;  // Variación aleatoria de pitch (0-100%)
~segmentStart = 0.0;  // Inicio del segmento (0-1)
~segmentEnd = 1.0;    // Fin del segmento (0-1)
~grains = List.new;
~isPlaying = false;
~waveformData = nil;  // Datos de la forma de onda

// Esperar a que el servidor esté listo
s.waitForBoot({
    // Definición del SynthDef granular
SynthDef(\granularLoFi, {
        |buf = 0, grainRate = 20, grainDur = 0.1, posFreq = 5, gain = 0.3, gate = 1, grainCount = 1, pitchVariation = 0.0, segmentStart = 0.0, segmentEnd = 1.0|
        var pos, sig, pan, env, grains;

        // Envelope para control de gate
        env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);

        // Generar múltiples granos simultáneos
        grains = Array.fill(8) { |i|
            var grainPos, grainPan, grainSig, grainActive, grainPitch;

            // Determinar si este grano está activo
            grainActive = (i < grainCount);

            // Posición aleatoria en el segmento seleccionado (más variación)
            grainPos = LFNoise1.kr(posFreq + (i * 0.3)).range(segmentStart, segmentEnd) * BufFrames.kr(buf);

            // Variación aleatoria de pitch para cada grano (más variación)
            grainPitch = 1.0 + (LFNoise1.kr(0.2 + (i * 0.4)) * pitchVariation);

            // Síntesis granular individual con trigger independiente
            grainSig = GrainBuf.ar(
        numChannels: 1,
                trigger: Impulse.kr(grainRate + (i * 0.1)) * grainActive,
        dur: grainDur,
        sndbuf: buf,
                rate: grainPitch,  // Pitch individual por grano
                pos: grainPos / BufFrames.kr(buf),
        interp: 2
    );

            // Panning aleatorio para cada grano (más variación)
            grainPan = LFNoise1.kr(0.5 + (i * 0.5)).range(-1, 1);

            // Aplicar panning y activación
            Pan2.ar(grainSig * grainActive, grainPan);
        };

        // Sumar todos los granos
        sig = Mix(grains);

    // Envío de triggers para visualización - CORREGIDO
    // Enviar un trigger por cada ciclo de granos (no por cada grano individual)
    SendTrig.kr(Impulse.kr(grainRate), 0, grainDur);

        // Aplicar ganancia y envelope
        sig = sig * gain * env;

    Out.ar(0, sig);
}).add;


    // Definición del OSCdef para visualización - CORREGIDO
    OSCdef(\drawGrain, { |msg|
        var dur = msg[3];
        var now = Main.elapsedTime;
        var activeGrains = 0;

        // Contar granos activos (no expirados)
        if (~grains.notNil and: { ~grains.size > 0 }) {
            ~grains.do { |grain|
                var age = now - grain[\time];
                if (age < grain[\dur]) {
                    activeGrains = activeGrains + 1;
                };
            };
        };

        // Agregar tantos granos visuales como granos de audio se están generando
        ~grainCount.do { |i|
            if (activeGrains < ~maxGrains) {
                var x = rrand(50, 550);
                var y = rrand(50, 350);
                ~grains.add((time: now, dur: ~grainDur, x: x, y: y, id: i));
                activeGrains = activeGrains + 1;
            };
        };

        // Forzar actualización inmediata
        if (~canvas.notNil) {
            { ~canvas.refresh }.defer;
        };
    }, '/tr');


    // Función para cargar archivo de audio
    ~loadSample = { |path|
        var sampleSize, step, indices;
    if (path.notNil) {
        if (~b.notNil) { ~b.free };
        ~b = Buffer.read(s, path, action: {
                "Sample cargado: %".format(path.basename).postln;

                // Esperar un momento para que el buffer se cargue completamente
                {
                // Cargar datos de la forma de onda (muestreo representativo de todo el sample)
                // Para un sample de 16 segundos a 48kHz = 768,000 muestras
                // Cargar una muestra representativa de todo el sample para visualización
                sampleSize = min(~b.numFrames, 10000); // Aumentar para mejor representación

                // Calcular step para muestrear todo el buffer, no solo el inicio
                step = max(1, (~b.numFrames / sampleSize).asInteger);
                indices = Array.series(sampleSize) * step;

                    // Cargar datos de forma de onda de forma más simple y confiable
                    try {
                        // Cargar una muestra representativa del buffer completo
                        // Usar loadToFloatArray que es más confiable que getn
                        ~b.loadToFloatArray(0, ~b.numFrames, { |data|
                            if (data.notNil and: { data.size > 0 }) {
                                // Reducir la resolución para visualización
                                var step = max(1, (data.size / sampleSize).asInteger);
                                var reducedData = Array.new(sampleSize);

                                // Muestrear los datos de forma distribuida
                                for (0, sampleSize - 1, { |i|
                                    var index = i * step;
                                    if (index < data.size) {
                                        reducedData.add(data[index]);
                                    };
                                });

                                ~waveformData = reducedData;
                                "Datos de forma de onda cargados: % muestras de % total (%.1f seg)".format(
                                    reducedData.size, ~b.numFrames, ~b.numFrames / 48000
                                ).postln;

                                // Refrescar visualizador de onda
                                if (~waveformView.notNil) {
                                    { ~waveformView.refresh }.defer;
                                };
                            } {
                                "Error: No se pudieron cargar los datos del buffer".postln;
                                // Crear datos de forma de onda de prueba
                                ~waveformData = Array.fill(1000, { |i| sin(i * 0.1) });
                                "Usando forma de onda de prueba".postln;

                                // Refrescar visualizador de onda
                                if (~waveformView.notNil) {
                                    { ~waveformView.refresh }.defer;
                                };
                            };
                        });

                    } { |error|
                        "Error cargando datos de forma de onda: %".format(error).postln;
                        // Crear datos de forma de onda de prueba
                        ~waveformData = Array.fill(1000, { |i| sin(i * 0.1) });
                        "Usando forma de onda de prueba".postln;

                        // Refrescar visualizador de onda
                        if (~waveformView.notNil) {
                            { ~waveformView.refresh }.defer;
                        };
                    };
                }.defer; // Ejecutar después de un frame

                if (~synth.notNil) { ~synth.free };
            ~synth = Synth(\granularLoFi, [
                \buf, ~b,
                \grainRate, ~grainRate,
                \grainDur, ~grainDur,
                \posFreq, ~grainPosFreq,
                    \gain, ~gain,
                    \grainCount, ~grainCount,
                    \pitchVariation, ~pitchVariation,
                    \segmentStart, ~segmentStart,
                    \segmentEnd, ~segmentEnd
                ]);
                "Sintetizador iniciado.".postln;

                // Actualizar información del sample
                if (~sampleInfoText.notNil) {
                    { ~sampleInfoText.string_("Sample: %\nDuración: % seg".format(
                        path.basename,
                        (~b.numFrames / s.sampleRate).round(0.01)
                    )) }.defer;
                };
            });
        };
    };

    // Función para detener el sintetizador
    ~stopSynth = {
        if (~synth.notNil) {
            ~synth.set(\gate, 0);
            ~synth = nil;
            ~isPlaying = false;
            "Sintetizador detenido.".postln;
        };
    };

    // Función para actualizar parámetros del sintetizador
    ~updateSynth = {
        if (~synth.notNil and: { ~isPlaying }) {
            ~synth.set(
                \grainRate, ~grainRate,
                \grainDur, ~grainDur,
                \posFreq, ~grainPosFreq,
                \gain, ~gain,
                \grainCount, ~grainCount,
                \pitchVariation, ~pitchVariation,
                \segmentStart, ~segmentStart,
                \segmentEnd, ~segmentEnd
            );
            "Sintetizador actualizado: Rate=%, Dur=%, LFO=%, Gain=%, Granos=%, Pitch=%, Segmento=%-%".format(~grainRate, ~grainDur, ~grainPosFreq, ~gain, ~grainCount, ~pitchVariation, ~segmentStart, ~segmentEnd).postln;
        };
    };

    // Función para limpiar la visualización
    ~clearGrains = {
        ~grains.clear;
        if (~canvas.notNil) {
            { ~canvas.refresh }.defer; // Forzar actualización del canvas
        };
        "Visualización limpiada.".postln;
    };

    // GUI Unificada
    ~createGUI = {
        var win, canvas, waveformView, controlsPanel, fileButton, playButton, stopButton, clearButton;

        // Cerrar ventanas existentes
        if (~mainWin.notNil) { ~mainWin.close };

        // Ventana principal
        ~mainWin = Window("4ssiz - Granular Synth", Rect(100, 100, 900, 600));

        // Panel de controles (lado izquierdo)
        controlsPanel = CompositeView(~mainWin, Rect(10, 10, 300, 580));
        controlsPanel.background = Color.grey(0.2);
        controlsPanel.decorator = FlowLayout(controlsPanel.bounds, 10@10, 5@5);

        // Título
        StaticText(controlsPanel, 280@30)
            .string_("CONTROLES")
            .font_(Font("Arial", 16, true))
            .align_(\center)
            .background_(Color.grey(0.3));

        // Botón para cargar archivo
        fileButton = Button(controlsPanel, 280@30)
            .states_([["Cargar Sample", Color.white, Color.blue]])
            .action_({
                Dialog.openPanel({ |path| ~loadSample.value(path) });
            });

        // Botón de control principal (toggle)
        playButton = Button(controlsPanel, 180@30)
            .states_([["PLAY", Color.white, Color.green], ["STOP", Color.white, Color.red]])
            .action_({ |btn|
                if (btn.value == 1) {
                    if (~b.notNil and: { ~synth.isNil }) {
                        ~synth = Synth(\granularLoFi, [
                            \buf, ~b,
                            \grainRate, ~grainRate,
                            \grainDur, ~grainDur,
                            \posFreq, ~grainPosFreq,
                            \gain, ~gain,
                            \grainCount, ~grainCount,
                            \pitchVariation, ~pitchVariation,
                            \segmentStart, ~segmentStart,
                            \segmentEnd, ~segmentEnd
                        ]);
                        ~isPlaying = true;
                    };
                } {
                    ~stopSynth.value;
    };
});

        clearButton = Button(controlsPanel, 90@30)
            .states_([["CLEAR", Color.white, Color.new(1, 0.5, 0)]])
            .action_({ ~clearGrains.value; });

        // Sliders de control
        EZSlider(controlsPanel, 280@40, "Rate", ControlSpec(1, 100, \lin, 1), {
            arg v; ~grainRate = v.value; 
            ~updateSynth.value;
        }).value_(~grainRate).labelColor_(Color.white);

        EZSlider(controlsPanel, 280@40, "Duración", ControlSpec(0.01, 0.5, \lin, 0.01), {
            arg v; ~grainDur = v.value;
            ~updateSynth.value;
        }).value_(~grainDur).labelColor_(Color.white);

        EZSlider(controlsPanel, 280@40, "LFO Pos", ControlSpec(0.1, 20, \lin, 0.1), {
            arg v; ~grainPosFreq = v.value;
            ~updateSynth.value;
        }).value_(~grainPosFreq).labelColor_(Color.white);

        EZSlider(controlsPanel, 280@40, "Volumen", ControlSpec(0, 1, \lin, 0.01), {
            arg v; ~gain = v.value;
            ~updateSynth.value;
        }).value_(~gain).labelColor_(Color.white);

        EZSlider(controlsPanel, 280@40, "Granos", ControlSpec(1, 8, \lin, 1), {
            arg v; ~grainCount = v.value;
            ~updateSynth.value; // Usar función de actualización
        }).value_(~grainCount).labelColor_(Color.white);

        EZSlider(controlsPanel, 280@40, "Pitch Var", ControlSpec(0, 1.0, \lin, 0.01), {
            arg v; ~pitchVariation = v.value;
            ~updateSynth.value;
        }).value_(~pitchVariation).labelColor_(Color.white);

        // Controles de segmento
        EZSlider(controlsPanel, 280@40, "Inicio", ControlSpec(0, 1, \lin, 0.01), {
            arg v; ~segmentStart = v.value;
            ~updateSynth.value;
            if (~waveformView.notNil) { { ~waveformView.refresh }.defer };
        }).value_(~segmentStart).labelColor_(Color.white);

        EZSlider(controlsPanel, 280@40, "Fin", ControlSpec(0, 1, \lin, 0.01), {
            arg v; ~segmentEnd = v.value;
            ~updateSynth.value;
            if (~waveformView.notNil) { { ~waveformView.refresh }.defer };
        }).value_(~segmentEnd).labelColor_(Color.white);

        // Información del sample
        ~sampleInfoText = StaticText(controlsPanel, 280@60)
            .string_("No hay sample cargado")
            .font_(Font("Arial", 10))
            .align_(\center)
            .background_(Color.grey(0.4));

        // Visualizador de onda (parte superior)
        waveformView = UserView(~mainWin, Rect(320, 10, 580, 200))
            .background_(Color.grey(0.1))
            .canFocus_(true);

        // Variables para drag and drop
        ~isDragging = false;
        ~dragStartX = 0;
        ~dragStartSegment = 0;

        ~waveformView = waveformView;

        // Eventos de mouse para drag and drop del segmento
        waveformView.mouseDownAction = { |view, x, y, modifiers, buttonNumber, clickCount|
            if (buttonNumber == 0) { // Botón izquierdo
                ~isDragging = true;
                ~dragStartX = x;
                ~dragStartSegment = ~segmentStart;
                "Iniciando drag del segmento".postln;
            };
        };

        waveformView.mouseMoveAction = { |view, x, y, modifiers|
            if (~isDragging) {
                var deltaX = x - ~dragStartX;
                var width = view.bounds.width;
                var deltaTime = deltaX / width; // Convertir píxeles a tiempo normalizado
                var newStart = ~dragStartSegment + deltaTime;
                var segmentWidth = ~segmentEnd - ~segmentStart;

                // Mantener el segmento dentro de los límites
                newStart = max(0, min(1 - segmentWidth, newStart));
                ~segmentStart = newStart;
                ~segmentEnd = newStart + segmentWidth;

                // Actualizar sintetizador y visualización
                if (~synth.notNil) {
                    ~synth.set(\segmentStart, ~segmentStart);
                    ~synth.set(\segmentEnd, ~segmentEnd);
                };
                { ~waveformView.refresh }.defer;
            };
        };

        waveformView.mouseUpAction = { |view, x, y, modifiers, buttonNumber|
            if (buttonNumber == 0) { // Botón izquierdo
                ~isDragging = false;
                "Drag del segmento completado".postln;
            };
        };

        // Panel de visualización de granos (parte inferior)
        canvas = UserView(~mainWin, Rect(320, 220, 580, 370))
    .background_(Color.black)
            .canFocus_(false);

        // Función para dibujar la forma de onda
        ~drawWaveform = {
            var width = 580;
            var height = 200;
            var startX, endX;
            var numFrames, stepSize, sampleData, sampleSize;

            // Limpiar canvas
            Pen.fillColor = Color.grey(0.1);
            Pen.fillRect(Rect(0, 0, width, height));



            // Dibujar línea central siempre
            Pen.strokeColor = Color.grey(0.5);
            Pen.width = 1;
            Pen.moveTo(0@(height/2));
            Pen.lineTo(width@(height/2));
            Pen.stroke;

            if (~waveformData.notNil and: { ~waveformData.size > 0 } and: { ~b.notNil }) {
                // Usar datos reales de la forma de onda
                // La forma de onda representa TODO el sample (16 segundos)
                // El segmento amarillo muestra la parte que se procesará
                stepSize = ~waveformData.size / width;

                // Dibujar forma de onda real del sample
                Pen.strokeColor = Color.white;
                Pen.width = 1;

                // Dibujar forma de onda real usando datos muestreados
                width.do { |x|
                    // Mapear directamente x a índice en los datos muestreados
                    var dataIndex = (x * ~waveformData.size / width).asInteger;
                    var sample = if (dataIndex >= 0 and: { dataIndex < ~waveformData.size }) {
                        ~waveformData[dataIndex]
                    } { 0 };
                    var y = height/2 + (sample * height * 0.4);

                    if (x == 0) {
                        Pen.moveTo(x@y);
                    } {
                        Pen.lineTo(x@y);
                    };
                };
                Pen.stroke;
            } {
                // Sin datos de forma de onda - dibujar forma de onda de prueba
                Pen.strokeColor = Color.cyan;
                Pen.width = 1;

                width.do { |x|
                    var y = height/2 + (sin(x * 0.02) * height * 0.3);
                    if (x == 0) {
                        Pen.moveTo(x@y);
                    } {
                        Pen.lineTo(x@y);
                    };
                };
                Pen.stroke;
            };

            // Dibujar segmento seleccionado SIEMPRE (fuera del bloque condicional)
            // El segmento representa la parte del sample que se procesará (máximo 1 segundo)
            // pero se muestra sobre la forma de onda completa
            startX = ~segmentStart * width;
            endX = ~segmentEnd * width;

            Pen.fillColor = Color.yellow.alpha_(0.3);
            // Dibujar segmento seleccionado con feedback visual
            if (~isDragging) {
                // Durante el drag, usar color más brillante
                Pen.fillColor = Color.new(1, 1, 0, 0.5); // Amarillo más opaco
                Pen.strokeColor = Color.new(1, 1, 0, 0.8); // Borde más brillante
            } {
                Pen.fillColor = Color.new(1, 1, 0, 0.3); // Amarillo semi-transparente
                Pen.strokeColor = Color.yellow; // Borde normal
            };

            Pen.fillRect(Rect(startX, 0, endX - startX, height));

            // Dibujar líneas de selección
            Pen.width = 2;
            Pen.moveTo(startX@0);
            Pen.lineTo(startX@height);
            Pen.stroke;

            Pen.moveTo(endX@0);
            Pen.lineTo(endX@height);
            Pen.stroke;

            // Información del segmento
            Pen.fillColor = Color.white;
            Pen.font = Font("Arial", 12);
            if (~b.notNil and: { ~b.numFrames.notNil }) {
                var sampleRate = 48000; // Usar sample rate fijo para evitar nil
                var totalDuration = ~b.numFrames / sampleRate;
                var segmentStartTime = ~segmentStart * totalDuration;
                var segmentEndTime = ~segmentEnd * totalDuration;
                var segmentDuration = segmentEndTime - segmentStartTime;

                Pen.stringAtPoint("Segmento: %.1f - %.1f seg".format(segmentStartTime, segmentEndTime), 10@10);
                Pen.stringAtPoint("Duración: %.1f seg".format(segmentDuration), 10@30);
                Pen.stringAtPoint("Sample: %.1f seg".format(totalDuration), 10@50);

                // Instrucciones de uso
                Pen.fillColor = Color.grey(0.7);
                Pen.font = Font("Arial", 10);
                Pen.stringAtPoint("Arrastra el segmento amarillo para navegar", 10@(height-30));
                Pen.stringAtPoint("o usa los sliders de Inicio/Fin", 10@(height-15));
            } {
                Pen.stringAtPoint("Segmento: % - %".format(~segmentStart.round(0.01), ~segmentEnd.round(0.01)), 10@10);
                Pen.stringAtPoint("Duración: %".format((~segmentEnd - ~segmentStart).round(0.01)), 10@30);
            };
        };

        // Función de dibujo separada - BASADA EN VERSIÓN ESTABLE
        ~drawGrains = {
            var now = Main.elapsedTime;
            var activeGrains = 0;

            // Limpiar canvas
            Pen.fillColor = Color.black;
            Pen.fillRect(Rect(0, 0, 580, 580));

            // Dibujar granos activos
            if (~grains.notNil and: { ~grains.size > 0 }) {
                ~grains.do { |grain|
                    var age = now - grain[\time];
                    if (age < grain[\dur]) {
                        var alpha = 1 - (age / grain[\dur]);
                        var x = grain[\x];
                        var y = grain[\y];
                        var size = 20 + (grain[\dur] * 80); // Tamaño variable como en versión estable
                        activeGrains = activeGrains + 1;

                        // Grano principal
                        Pen.fillColor = Color.white.alpha_(alpha);
                        Pen.fillOval(Rect(x - size/2, y - size/2, size, size));

                        // Borde del grano
                        Pen.strokeColor = Color.cyan.alpha_(alpha);
                        Pen.width = 4; // Borde más grueso como en versión estable
                        Pen.strokeOval(Rect(x - size/2, y - size/2, size, size));
                    };
                };
            };

            // Dibujar información
            Pen.fillColor = Color.white;
            Pen.font = Font("Arial", 16);
            Pen.stringAtPoint("Granos activos: %".format(activeGrains), 10@10);
            Pen.stringAtPoint("Rate: % | Dur: % | LFO: %".format(~grainRate, ~grainDur, ~grainPosFreq), 10@35);
            Pen.stringAtPoint("Total granos: %".format(~grains.size), 10@60);
        };

        // Asignar funciones de dibujo
        waveformView.drawFunc = ~drawWaveform;
        canvas.drawFunc = ~drawGrains;

        ~canvas = canvas;

        // Confirmar creación del canvas
        "Canvas creado en posición: %".format(canvas.bounds).postln;

        // Tarea de actualización de la visualización - BASADA EN VERSIÓN ESTABLE
        ~refreshTask = Task({
            loop {
                if (~canvas.notNil) {
                    // Limpiar granos antiguos cada 2 segundos (como versión estable)
                    if (Main.elapsedTime % 2 < 0.05) {
                        var now = Main.elapsedTime;
                        ~grains = ~grains.select { |grain|
                            var age = now - grain[\time];
                            age < grain[\dur];
                        };
                    };
                    ~canvas.refresh; // Refresco directo como en versión estable
                };
                if (~waveformView.notNil) {
                    { ~waveformView.refresh }.defer;
                };
                0.05.wait; // Misma tasa que versión estable
            }
        }).play; // Usar .play en lugar de .start(AppClock)

        // Mostrar ventana
        ~mainWin.front;

        // Limpiar al cerrar
        ~mainWin.onClose = {
            if (~refreshTask.notNil) { ~refreshTask.stop };
            if (~synth.notNil) { ~synth.free };
        };
    };

    // Función de debug para verificar triggers
    ~debugTriggers = {
        "=== DEBUG TRIGGERS ===".postln;
        "OSCdef registrado: %".format(OSCdef(\drawGrain).notNil).postln;
        "OSCdef activo: %".format(OSCdef(\drawGrain).isActive).postln;
        "Grains en lista: %".format(~grains.size).postln;
        "Servidor corriendo: %".format(s.serverRunning).postln;
        "Canvas definido: %".format(~canvas.notNil).postln;
        "Refresh task corriendo: %".format(~refreshTask.notNil).postln;
        "Sintetizador activo: %".format(~synth.notNil).postln;
        "GrainCount configurado: %".format(~grainCount).postln;
        "GrainRate configurado: %".format(~grainRate).postln;
        "Buffer cargado: %".format(~b.notNil).postln;
        if (~b.notNil) {
            "Buffer frames: %".format(~b.numFrames).postln;
        };

        // Verificar si hay mensajes OSC pendientes
        "Verificando mensajes OSC...".postln;
    };

    // Función para probar triggers manualmente
    ~testOSC = {
        var testMsg = ['/tr', 0, 0, 0.5]; // [path, nodeID, grainID, duration]
        "=== PRUEBA OSC MANUAL ===".postln;
        "Enviando mensaje de prueba: %".format(testMsg).postln;
        OSCdef(\drawGrain).value(testMsg, 0, NetAddr("127.0.0.1", 57120));
    };

    // Función para verificar sincronización audio-visual
    ~checkSync = {
        var now = Main.elapsedTime;
        var activeGrains = 0;

        if (~grains.notNil) {
        ~grains.do { |grain|
            var age = now - grain[\time];
            if (age < grain[\dur]) {
                    activeGrains = activeGrains + 1;
                };
            };
        };

        "=== SINCRONIZACIÓN ===".postln;
        "Granos en lista: %".format(~grains.size).postln;
        "Granos activos: %".format(activeGrains).postln;
        "Tasa de granos configurada: %".format(~grainRate).postln;
        "Duración de granos: %".format(~grainDur).postln;
        "Granos simultáneos: %".format(~grainCount).postln;
        "Tasa de refresco: 20 FPS".postln;
    };

    // Función de prueba para agregar granos manualmente
    ~testGrain = {
        var now = Main.elapsedTime;
        var x = rrand(50, 550);
        var y = rrand(50, 350);
        var dur = 5.0; // 5 segundos de duración para debug

        ~grains.add((time: now, dur: dur, x: x, y: y, id: 999));
        "GRANO DE PRUEBA AGREGADO: Pos=(%,%), Duración=%, Tiempo=%".format(x, y, dur, now).postln;

        if (~canvas.notNil) {
            { ~canvas.refresh }.defer;
            "CANVAS REFRESHED MANUALMENTE".postln;
        } {
            "ERROR: Canvas no disponible".postln;
        };
    };

    // Función para simular triggers manualmente
    ~simulateTrigger = {
        var now = Main.elapsedTime;
        var x = rrand(50, 550);
        var y = rrand(50, 350);
        var dur = 3.0;

        "SIMULANDO TRIGGER MANUAL".postln;
        ~grains.add((time: now, dur: dur, x: x, y: y, id: 888));
        "GRANO SIMULADO AGREGADO: Total=%".format(~grains.size).postln;

        if (~canvas.notNil) {
            { ~canvas.refresh }.defer;
        };
    };

    // Función para probar el sistema completo
    ~testSystem = {
        "=== PRUEBA DEL SISTEMA DEBUG ===".postln;
        "Canvas disponible: %".format(~canvas.notNil).postln;
        "Grains lista: %".format(~grains.size).postln;
        "Sintetizador activo: %".format(~synth.notNil).postln;
        "OSCdef registrado: %".format(OSCdef(\drawGrain).notNil).postln;

        // Limpiar granos existentes
        ~grains.clear;
        "Lista de granos limpiada".postln;

        // Agregar grano de prueba
        ~testGrain.value;

        // Simular trigger
        ~simulateTrigger.value;

        // Verificar después de 2 segundos
        {
            2.wait;
            "Después de 2 segundos:".postln;
            "Granos en lista: %".format(~grains.size).postln;
            "Canvas disponible: %".format(~canvas.notNil).postln;
            "Tiempo actual: %".format(Main.elapsedTime).postln;
        }.fork;
    };

    // Función para forzar dibujo manual
    ~forceDraw = {
        if (~canvas.notNil) {
            "Forzando dibujo manual...".postln;
            ~canvas.refresh;
            "Dibujo forzado completado".postln;
        } {
            "ERROR: Canvas no disponible".postln;
        };
    };

    // Función para limpiar y reiniciar
    ~resetGrains = {
        ~grains.clear;
        "Lista de granos limpiada".postln;
        if (~canvas.notNil) {
            ~canvas.refresh;
        };
    };

    // Función de test para verificar el sistema
    ~testGrainSystem = {
        var testMsg = ['/tr', 0, 0, 0.5];

        "=== TEST DEL SISTEMA DE GRANOS ===".postln;
        "OSCdef activo: %".format(OSCdef(\drawGrain).isActive).postln;
        "Canvas existe: %".format(~canvas.notNil).postln;
        "Grains array existe: %".format(~grains.notNil).postln;
        "Grains size: %".format(if (~grains.notNil) { ~grains.size } { "NIL" }).postln;
        "Synth activo: %".format(~synth.notNil).postln;
        "GrainRate: %, GrainDur: %, GrainCount: %".format(~grainRate, ~grainDur, ~grainCount).postln;

        // Simular un trigger manual
        "Simulando trigger manual...".postln;
        OSCdef(\drawGrain).value(testMsg, 0, NetAddr("127.0.0.1", 57120));
    };

    // Función para simular granos manualmente
    ~simulateGrain = {
        var now = Main.elapsedTime;
        var x = rrand(50, 550);
        var y = rrand(50, 350);

        "SIMULANDO GRANO MANUAL".postln;
        ~grains.add((time: now, dur: 2.0, x: x, y: y, id: 999));

        if (~canvas.notNil) {
            { ~canvas.refresh }.defer;
        };
    };

    // Función de test para verificar el dibujo
    ~testDrawing = {
        var now = Main.elapsedTime;
        "TEST DIBUJO: Agregando 5 granos de prueba".postln;
        5.do {
            var x = rrand(50, 550);
            var y = rrand(50, 350);
            ~grains.add((time: now, dur: 5.0, x: x, y: y, id: 3000 + rrand(0, 999)));
        };
        "TEST DIBUJO: Total granos: %".format(~grains.size).postln;
        if (~canvas.notNil) {
            { ~canvas.refresh }.defer;
        };
    };

    // Función simplificada para limpiar granos expirados
    ~cleanExpiredGrains = {
        var now = Main.elapsedTime;
        if (~grains.notNil and: { ~grains.size > 0 }) {
            var oldSize = ~grains.size;
            ~grains = ~grains.select { |grain|
                var age = now - grain[\time];
                age < grain[\dur];
            };
            if (oldSize != ~grains.size) {
                "Limpieza: % -> % granos".format(oldSize, ~grains.size).postln;
            };
        };
    };

    // Crear la GUI
    ~createGUI.value;

    "Sistema inicializado correctamente.".postln;
    "Sistema optimizado: Máximo % granos simultáneos, basado en versión estable.".format(~maxGrains).postln;
    "Controles actualizados: Todos los sliders actualizan el sintetizador en tiempo real.".postln;
    "Usa ~testDrawing.value para probar el dibujo de granos.".postln;
    "Usa ~cleanExpiredGrains.value para limpiar granos expirados.".postln;
});
