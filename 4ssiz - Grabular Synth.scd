// ===============================================
// 4ssiz - Granular Synth
// Trabajo Final - Teoría del Audio Digital
// Universidad Nacional de las Artes
// ===============================================

// Inicializar servidor
s.boot;

// Variables globales
~grainRate = 50;
~grainDur = 0.1;
~grainPosFreq = 5;
~gain = 0.3;
~grainCount = 1;  // Cantidad de granos simultáneos
~pitchVariation = 0.0;  // Variación aleatoria de pitch (0-100%)
~useGenerator = false;  // Usar generador interno en lugar de sample
~genFreq = 440;   // Frecuencia del generador
~genWaveType = 0; // Tipo de onda del generador
~grains = List.new;
~isPlaying = false;

// Esperar a que el servidor esté listo
s.waitForBoot({
    // Definición del SynthDef granular
    SynthDef(\granularLoFi, {
        |buf = 0, grainRate = 20, grainDur = 0.1, posFreq = 5, gain = 0.3, gate = 1, grainCount = 1, pitchVariation = 0.0|
        var pos, sig, pan, env, grains;
        
        // Envelope para control de gate
        env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
        
        // Generar múltiples granos simultáneos
        grains = Array.fill(8) { |i|
            var grainPos, grainPan, grainSig, grainActive, grainPitch;
            
            // Determinar si este grano está activo
            grainActive = (i < grainCount);
            
            // Posición aleatoria en el buffer controlada por LFO
            grainPos = LFNoise1.kr(posFreq + (i * 0.1)).range(0, BufFrames.kr(buf));
            
            // Variación aleatoria de pitch para cada grano
            grainPitch = 1.0 + (LFNoise1.kr(0.5 + (i * 0.2)) * pitchVariation);
            
            // Síntesis granular individual
            grainSig = GrainBuf.ar(
                numChannels: 1,
                trigger: Impulse.kr(grainRate) * grainActive,
                dur: grainDur,
                sndbuf: buf,
                rate: grainPitch,  // Pitch individual por grano
                pos: grainPos / BufFrames.kr(buf),
                interp: 2
            );
            
            // Panning aleatorio para cada grano
            grainPan = LFNoise1.kr(1 + (i * 0.3)).range(-1, 1);
            
            // Aplicar panning y activación
            Pan2.ar(grainSig * grainActive, grainPan);
        };
        
        // Sumar todos los granos
        sig = Mix(grains);
        
        // Envío de triggers para visualización (uno por grano activo)
        8.do { |i|
            var grainActive = (i < grainCount);
            SendTrig.kr(Impulse.kr(grainRate) * grainActive, i, grainDur);
        };
        
        // Aplicar ganancia y envelope
        sig = sig * gain * env;

        Out.ar(0, sig);
    }).add;
    
    // SynthDef para generadores internos
    SynthDef(\generator, {
        |freq = 440, amp = 0.3, gate = 1, waveType = 0|
        var sig, env;
        
        env = EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
        
        sig = Select.ar(waveType, [
            SinOsc.ar(freq),                           // 0: Sinusoidal
            Saw.ar(freq),                              // 1: Diente de sierra
            Pulse.ar(freq, 0.5),                       // 2: Cuadrada
            WhiteNoise.ar,                             // 3: Ruido blanco
            PinkNoise.ar,                              // 4: Ruido rosa
            BrownNoise.ar,                             // 5: Ruido marrón
            LFSaw.ar(freq) * SinOsc.ar(freq * 2),      // 6: FM simple
            Formant.ar(freq, freq * 1.5, freq * 2)     // 7: Formantes
        ]);
        
        sig = sig * amp * env;
        Out.ar(0, sig);
    }).add;
    
    // Definición del OSCdef para visualización
    OSCdef(\drawGrain, { |msg|
        var dur = msg[3];
        var now = Main.elapsedTime;
        var x = rrand(50, 550);  // Ajustado para el área de visualización
        var y = rrand(50, 530);  // Ajustado para el área de visualización
        ~grains.add((time: now, dur: dur, x: x, y: y));
        // Forzar actualización inmediata
        if (~canvas.notNil) {
            { ~canvas.refresh }.defer;
        };
    }, '/tr');
    
    // Función para generar buffer sintético
    ~generateBuffer = { |freq = 440, waveType = 0, duration = 2.0|
        if (~b.notNil) { ~b.free };
        ~b = Buffer.alloc(s, s.sampleRate * duration, 1);
        ~b.sine1(1.0, true, true, true, 0, 0, {
            "Buffer sintético generado: % Hz, tipo %".format(freq, waveType).postln;
            if (~synth.notNil) { ~synth.free };
            ~synth = Synth(\granularLoFi, [
                \buf, ~b,
                \grainRate, ~grainRate,
                \grainDur, ~grainDur,
                \posFreq, ~grainPosFreq,
                \gain, ~gain,
                \grainCount, ~grainCount,
                \pitchVariation, ~pitchVariation
            ]);
            ~isPlaying = true;
            "Sintetizador iniciado con generador.".postln;
        });
    };

    // Función para cargar archivo de audio
    ~loadSample = { |path|
        if (path.notNil) {
            if (~b.notNil) { ~b.free };
            ~b = Buffer.read(s, path, action: {
                "Sample cargado: %".format(path.basename).postln;
                if (~synth.notNil) { ~synth.free };
                ~synth = Synth(\granularLoFi, [
                    \buf, ~b,
                    \grainRate, ~grainRate,
                    \grainDur, ~grainDur,
                    \posFreq, ~grainPosFreq,
                    \gain, ~gain,
                    \grainCount, ~grainCount,
                    \pitchVariation, ~pitchVariation
                ]);
                ~isPlaying = true;
                "Sintetizador iniciado.".postln;
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

    // Función para limpiar la visualización
    ~clearGrains = {
        ~grains.clear;
        "Visualización limpiada.".postln;
    };

    // GUI Unificada
    ~createGUI = {
        var win, canvas, controlsPanel, fileButton, genButton, playButton, stopButton, clearButton;
        
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
        
        // Botones para fuente de audio
        fileButton = Button(controlsPanel, 140@30)
            .states_([["Cargar Sample", Color.white, Color.blue]])
            .action_({
                Dialog.openPanel({ |path| ~loadSample.value(path) });
            });
        
        genButton = Button(controlsPanel, 140@30)
            .states_([["Generar Audio", Color.white, Color.green]])
            .action_({
                ~generateBuffer.value(~genFreq, ~genWaveType, 2.0);
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
                            \gain, ~gain
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
            if (~synth.notNil) { ~synth.set(\grainRate, v.value) }
        }).value_(~grainRate);

        EZSlider(controlsPanel, 280@40, "Duración", ControlSpec(0.01, 0.5, \lin, 0.01), {
            arg v; ~grainDur = v.value; 
            if (~synth.notNil) { ~synth.set(\grainDur, v.value) }
        }).value_(~grainDur);

        EZSlider(controlsPanel, 280@40, "LFO Pos", ControlSpec(0.1, 20, \lin, 0.1), {
            arg v; ~grainPosFreq = v.value; 
            if (~synth.notNil) { ~synth.set(\posFreq, v.value) }
        }).value_(~grainPosFreq);

        EZSlider(controlsPanel, 280@40, "Volumen", ControlSpec(0, 1, \lin, 0.01), {
            arg v; ~gain = v.value; 
            if (~synth.notNil) { ~synth.set(\gain, v.value) }
        }).value_(~gain);

        EZSlider(controlsPanel, 280@40, "Granos", ControlSpec(1, 8, \lin, 1), {
            arg v; ~grainCount = v.value; 
            if (~synth.notNil) { ~synth.set(\grainCount, v.value) }
        }).value_(~grainCount);

        EZSlider(controlsPanel, 280@40, "Pitch Var", ControlSpec(0, 1.0, \lin, 0.01), {
            arg v; ~pitchVariation = v.value; 
            if (~synth.notNil) { ~synth.set(\pitchVariation, v.value) }
        }).value_(~pitchVariation);

        // Controles del generador
        EZSlider(controlsPanel, 280@40, "Gen Freq", ControlSpec(50, 2000, \exp, 1), {
            arg v; ~genFreq = v.value; 
        }).value_(~genFreq);

        EZSlider(controlsPanel, 280@40, "Gen Wave", ControlSpec(0, 7, \lin, 1), {
            arg v; ~genWaveType = v.value; 
        }).value_(~genWaveType);
        
        // Información del sample
        StaticText(controlsPanel, 280@60)
            .string_("No hay sample cargado")
            .font_(Font("Arial", 10))
            .align_(\center)
            .background_(Color.grey(0.4));
        
        // Panel de visualización (lado derecho)
        canvas = UserView(~mainWin, Rect(320, 10, 580, 580))
            .background_(Color.black)
            .canFocus_(false);
        
        // Función de dibujo separada
        ~drawGrains = {
            var now = Main.elapsedTime;
            var activeGrains = 0;
            
            // Limpiar canvas
            Pen.fillColor = Color.black;
            Pen.fillRect(Rect(0, 0, 580, 580));
            
            // Dibujar granos
            if (~grains.notNil and: { ~grains.size > 0 }) {
                ~grains.do { |grain|
                    var age = now - grain[\time];
                    if (age < grain[\dur]) {
                        var alpha = 1 - (age / grain[\dur]);
                        var x = grain[\x];
                        var y = grain[\y];
                        var size = 20 + (grain[\dur] * 80);
                        activeGrains = activeGrains + 1;
                        
                        // Grano principal
                        Pen.fillColor = Color.white.alpha_(alpha);
                        Pen.fillOval(Rect(x - size/2, y - size/2, size, size));
                        
                        // Borde del grano
                        Pen.strokeColor = Color.cyan.alpha_(alpha);
                        Pen.width = 4;
                        Pen.strokeOval(Rect(x - size/2, y - size/2, size, size));
                    };
                };
            };
            
            // Dibujar información
            Pen.fillColor = Color.white;
            Pen.font = Font("Arial", 16);
            Pen.stringAtPoint("Granos activos: %".format(activeGrains), 10@10);
            Pen.stringAtPoint("Rate: % | Dur: % | LFO: %".format(~grainRate, ~grainDur, ~grainPosFreq), 10@35);
            Pen.stringAtPoint("Granos: % | Pitch Var: % | Total: %".format(~grainCount, (~pitchVariation * 100).round(1), ~grains.size), 10@60);
            Pen.stringAtPoint("Gen: % Hz | Wave: %".format(~genFreq.round(1), ~genWaveType), 10@85);
        };
        
        // Asignar función de dibujo
        canvas.drawFunc = ~drawGrains;
        
        ~canvas = canvas;
        
        // Confirmar creación del canvas
        "Canvas creado en posición: %".format(canvas.bounds).postln;
        
        // Tarea de actualización de la visualización
        ~refreshTask = Task({
            loop {
                if (~canvas.notNil) {
                    // Limpiar granos antiguos cada 2 segundos
                    if (Main.elapsedTime % 2 < 0.05) {
                        var now = Main.elapsedTime;
                        ~grains = ~grains.select { |grain|
                            var age = now - grain[\time];
                            age < grain[\dur];
                        };
                    };
                    ~canvas.refresh;
                };
                0.05.wait;
            }
        }).play;
        
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
        "Grains en lista: %".format(~grains.size).postln;
        "Servidor corriendo: %".format(s.serverRunning).postln;
        "Canvas definido: %".format(~canvas.notNil).postln;
        "Refresh task corriendo: %".format(~refreshTask.notNil).postln;
    };
    
    // Función para forzar actualización
    ~forceRefresh = {
        if (~canvas.notNil) {
            ~canvas.refresh;
            "Canvas actualizado forzadamente".postln;
        } {
            "Canvas no disponible".postln;
        };
    };
    
    // Función para actualizar la función de dibujo
    ~updateDrawFunc = {
        if (~canvas.notNil) {
            ~canvas.drawFunc = ~drawGrains;
            "Función de dibujo actualizada".postln;
        };
    };
    
    // Función para limpiar granos antiguos
    ~cleanOldGrains = {
        var now = Main.elapsedTime;
        var oldSize = ~grains.size;
        ~grains = ~grains.select { |grain|
            var age = now - grain[\time];
            age < grain[\dur];
        };
        "Granos limpiados: % -> %".format(oldSize, ~grains.size).postln;
    };
    
    
    // Crear la GUI
    ~createGUI.value;
    
    "Sistema inicializado correctamente.".postln;
    "Usa ~debugTriggers.value para verificar el sistema.".postln;
});
