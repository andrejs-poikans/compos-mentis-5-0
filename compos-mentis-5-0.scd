
//compos-mentis 5-0, an editable infrastructure
//for Jon Heilbron and Rebecca Lane
//to accompany Cenk Ergün's composition "Compos Mentis"

//works with supercollider 3.13.0 on MacOS Tahoe 26.0.1 (Apple Silicon)
//release date: 21-11-2025

// software developed by Andrejs Poikāns
/*
░░              ░░
                ░░              ░░
                  ░░    ▒▒▒▒░░░░  ░░
            ░░░░░░▒▒  ░░  ░░  ░░░░░░
            ░░  ▒▒░░            ▒▒  ░░
          ░░    ▒▒░░            ▒▒  ░░▒▒          ▒▒
          ▒▒  ░░▒▒░░░░  ▒▒      ░░▒▒  ░░░░
                ░░  ░░░░▒▒        ░░▒▒░░░░        ░░
                ░░▒▒  ░░▒▒    ░░░░  ░░▓▓░░        ░░
              ░░  ░░▒▒░░░░░░  ░░░░▒▒    ▒▒░░      ▒▒
                ░░  ▒▒░░░░▒▒        ░░    ▒▒    ░░▒▒
                ░░  ▓▓  ░░  ▓▓      ▒▒    ▒▒    ░░░░
                  ▒▒▒▒    ░░▓▓        ▒▒  ▒▒    ░░░░▒▒
                    ▓▓░░  ░░  ▒▒        ░░▓▓    ░░░░██
                      ▒▒  ░░░░  ░░░░      ▓▓    ░░▓▓
                        ▓▓    ▒▒░░▓▓        ░░    ▓▓  ▓▓
                        ░░▓▓▒▒      ▒▒      ░░  ░░░░  ▒▒
                              ▒▒▓▓██░░▒▒  ░░      ░░    ▒▒
                                      ▒▒▒▒░░        ▒▒  ░░
                                        ▒▒▓▓        ░░▒▒
                                          ▓▓          ▒▒
                                          ░░██      ░░░░
                                            ██      ▒▒
                                            ▓▓      ▓▓
                                            ░░░░    ▒▒
                                              ▓▓  ▒▒
                                              ▓▓░░▓▓
                                              ░░▓▓▒▒
                                                ▓▓
                                                ██
                                                ▓▓
                                                ▓▓
                                                ██░░
*/

(

Server.local.options.sampleRate = 44100;
Server.internal.options.sampleRate = 44100;
~path = (PathName(thisProcess.nowExecutingPath)).pathOnly;
~currentPath = ~path ++ "presets/base";

s.waitForBoot({

	~func = {
	(
		//////////////////////////////////////////////////////////////////////////
		// load samples

		Buffer.freeAll(s);

		~buf = SoundFile.collectIntoBuffers(~path ++ "samples/*", s);
		~silent = Buffer.alloc(s, s.sampleRate * 8.0, 2);
		~limitBus = Bus.audio(s, numChannels: 2);

		"samples and busses loaded".postln;

		(1/10).wait;
		//////////////////////////////////////////////////////////////////////////
		// load synths

		SynthDef(\playback, {
			|bufnum = 1, amp = 1, pan = 0.0, loop = 0, trig = 0|
			var sig;
			sig = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), trig, loop:loop, doneAction:2);
			sig = sig*amp;
			sig = Balance2.ar(sig[0], sig[1], pan);
			Out.ar(~limitBus, sig);
		}).add;

		SynthDef(\limit, {
			var sig, in;
			in = InBus.ar(~limitBus, 2);
			sig = Limiter.ar(in);
			Out.ar(0, sig);
		}).add;

		"synths loaded".postln;

		(1/10).wait;

		//////////////////////////////////////////////////////////////////////////
		// load tones
		~reader = Object.readArchive(~currentPath);
		~tone_list = ~reader[0];
		~toneName = ~reader[1];
		~sampleList = ~reader[2];
		~proximity = ~reader[3];
		~deviation = ~reader[4];
		~density = ~reader[5];
		~amp = ~reader[6];
		~pan = ~reader[7];
		~currentCueArray = ~reader[8];
		~forwardBtn = ~reader[9];
		~backwardBtn = ~reader[10];
		~cueSpace = ~reader[11];
		~cueNum = ~reader[12];

		~formatToneList = {
		~tone_list.size.do({ |i|
			if(~tone_list[i].isString, {
				~tone_list[i] = ~tone_list[i].split($,).collect(_.stripWhiteSpace);
			});
			~tone_list[i].postln;
		});
		};

		~formatToneList.value;

		//make a sample list for the selection
		~sampleList = Array.fill(~buf.size, {|i| ~buf[i].path.basename.splitext[0].asString});

		~cue_tones = Array.fill(~currentCueArray.size, \nil);

		// sort in relation to name
		~makeToneList = {
			~tone_list.size.do{|l|
				var tone = ~tone_list[l];
				~cue_tones[l] = Array.fill(tone.size, \nil);
				~buf.size.do{|i|
					tone.size.do{|n|
						if(~buf[i].path.basename.splitext[0] == tone[n],
							{
								["yes...................", i].postln;
								~cue_tones[l].put(n, ~buf[i]);
							},{
								if(tone[n] == "-",{
									~cue_tones[l].put(n, ~silent);
								});
						});
					};
				};
				~cue_tones[l].postln;
			};
		};

		~makeToneList.value;

		"parameters, list of samples loaded".postln;

		(1/10).wait;

		//////////////////////////////////////////////////////////////////////////////////////////////////
		// playback

		// for mapping the new cueSpaces
		~densityType = ["low", "medium", "high", "silent"];
		~low = [[3, 6], ~proximity[0], ~deviation[0], ~densityType[0]];
		~medium = [[5, 10], ~proximity[1], ~deviation[1], ~densityType[1]];
		~high = [[7, 14], ~proximity[2], ~deviation[2], ~densityType[2]];
		~pause = [[1, 1], ~proximity[0], ~deviation[0], ~densityType[3]];

		//define a cue space which we can add or take latter
		~cueSpace = [~density, ~cue_tones];

		(
			t = Task({
				{
					var density = rrand(~cueSpace[0][~cue][0][0], ~cueSpace[0][~cue][0][1]);

					if(~cueSpace[0][~cue][3] == "silent", {
						"silent".postln;
					}, {
						density.do{
							var
							sample = ~cueSpace[1][~cue].choose,
							amp = rrand(~amp[0], ~amp[1]),
							pan = rrand(~pan[0], ~pan[1]);

							Synth(\playback, [\bufnum, sample, \amp, amp, \pan, pan]);
							rrand(~cueSpace[0][~cue][2][0], ~cueSpace[0][~cue][2][1]).wait;
						};
					});

					rrand(~cueSpace[0][~cue][1][0], ~cueSpace[0][~cue][1][1]).wait;
				}.loop;
			});
		);


		"task defined".postln;
	);

	//////////////////////////////////////////////////////////////////////////////////////////////////
	// gui
		(1/10).wait;
	(

		~color = [
			Color.blue(1.0),
			Color.magenta(1.0),
			Color.yellow(1.0),
			Color.black,
			Color.white,
			Color.gray,
			Color.red,
			Color.green
		];

		~current = 0;
		~cue = 0;

		~mapToSlider = { |val, lo, hi| val.linlin(lo, hi, 0, 1) };
		~mapFromSlider = { |val, lo, hi| val.linlin(0, 1, lo, hi) };


		// meter
		~out =  Server.local.options.numOutputBusChannels;
		~wMeter = Window.new("scope",
			Rect(
				100,
				Window.screenBounds.height / 2 - 150,
				90,
				230
			)
		)
		.front
		.alwaysOnTop = true;
		~uMeter = ServerMeterView.new(s, ~wMeter, 0@0, 0, ~out);


		~buttonPlay = Button()
		.states_([
			["PLAY", ~color[2], ~color[0]],
			["STOP", ~color[3], ~color[6]]
		]);

		//////////////////////////////////////////////////////////////////////////////////////////////////
		// global variables

		~globalVarButton = Button()
		.states_([
			["global variables", Color.black],
			["close global variables", Color.red]
		]);


		~currentAmpVal = Array.fill(~amp.size, {|i| ~amp[i]});
		~currentPanVal = Array.fill(~pan.size, {|i| ~pan[i]});

		~currentDev = ~deviation.collect { |arr| arr.copy };
		~currentProximity = ~proximity.collect { |arr| arr.copy };

		~memoryAmpVal = ~amp.collect { |arr| arr.copy };
		~memoryPanVal = ~pan.collect { |arr| arr.copy };
		~memoryDev = ~currentDev.copy;
		~memoryProximity = ~currentProximity.copy;

		~globalVarButton.action_({	|a|

			if(a.value == 1, {

				~globalText = Array.fill(6, {|i| StaticText()});
				~globalText[0].string = "---------------------------/edit amplitude & pan/---------------------------";
				~globalText[1].string = "Amp range (1.0 = 0db, 0.5 = -6db, 0.0 = -48db)";
				~globalText[2].string = "Pan range (max L = 0.0, max R = 1.0, center = 0.5)";
				~globalText[3].string = "---------------------------/edit density/---------------------------";
				~globalText[4].string = "deviation – the range of time in seconds which defines the length of the cue loop (relates to proximity – if deviation is 2.0-7.0 sec and proximity is 0.1-0.7 sec, then the lenght of the loop is in the range of 2.1-7.7)";
				~globalText[5].string = "proximity – the slight time offset in seconds of the playback of each sample within the given loop";

				~globalText[0].align_(\center).stringColor_(~color[0]);
				~globalText[3].align_(\center).stringColor_(~color[0]);

				~globalNum = Array.fill(8, {|i| StaticText()});
				~globalNum[0].string = ~amp[0].asString;
				~globalNum[1].string = ~amp[1].asString;
				~globalNum[2].string = ~pan[0].asString;
				~globalNum[3].string = ~pan[1].asString;
				~globalNum[4].string = ~deviation[0][0].asString;
				~globalNum[5].string = ~deviation[0][1].asString;
				~globalNum[6].string = ~proximity[0][0].asString;
				~globalNum[7].string = ~proximity[0][1].asString;


				~resetGlobalButton = Button()
				.states_([
					["reset all global variables", Color.black],
				]);

				~resetGlobalButton.action_({

					~currentDev = ~memoryDev;
					~currentProximity = ~memoryProximity;

					~currentAmpVal = ~memoryAmpVal;
					~currentPanVal = ~memoryPanVal;

					{
						var min = 0.01, max = 1.5;
						~sAmp.setSpanActive(~mapToSlider.(~currentAmpVal[0], min, max),~mapToSlider.(~currentAmpVal[1], min, max));
					}.value;

					{
						var min = -1.0, max = 1.0;
						~sPan.setSpanActive(~mapToSlider.(~currentPanVal[0], min, max),~mapToSlider.(~currentPanVal[1], min, max));
					}.value;


					~sDev.size.do({|i|
						var min = 0.01, max = 1.0;
						~sDev[i].setSpanActive(
							~mapToSlider.(~currentDev[i][0], min, max),
							~mapToSlider.(~currentDev[i][1], min, max)
						);

					});

					~sProx.size.do({|i|
						var min = 0.1, max = 14.0;
						~sProx[i].setSpanActive(
							~mapToSlider.(~currentProximity[i][0], min, max),
							~mapToSlider.(~currentProximity[i][1], min, max)
						);
					});

				});


				(
					{
						var min = 0.01, max = 1.5;
						~sAmp = RangeSlider()
						.lo_(~mapToSlider.(~currentAmpVal[0], min, max))
						.hi_(~mapToSlider.(~currentAmpVal[1], min, max))
						.orientation_(\horizontal)
						.knobColor_(Color.gray(0.5))
						.background_(~color[0])
						.decrement(1.0)
						.action_({ |slider|
							~currentAmpVal[0] = ~mapFromSlider.(slider.lo, min, max).round(0.01);
							~amp[0] = ~currentAmpVal[0];
							~currentAmpVal[1] = ~mapFromSlider.(slider.hi, min, max).round(0.01);
							~amp[1] = ~currentAmpVal[1];
							[\sliderLOW, ~currentAmpVal[0], \sliderHI, ~currentAmpVal[1]].postln;
						});
					}.value;
				);
				(
					{
						var min = -1.0, max = 1.0;
						~sPan = RangeSlider()
						.lo_(~mapToSlider.(~currentPanVal[0], min, max))
						.hi_(~mapToSlider.(~currentPanVal[1], min, max))
						.orientation_(\horizontal)
						.knobColor_(Color.gray(0.5))
						.background_(~color[0])
						.action_({ |slider|
							~currentPanVal[0] = ~mapFromSlider.(slider.lo, min, max).round(0.01);
							~pan[0] = ~currentPanVal[0];
							~currentPanVal[1] = ~mapFromSlider.(slider.hi, min, max).round(0.01);
							~pan[1] = ~currentPanVal[1];
							[\sliderLOW, ~currentPanVal[0], \sliderHI,~currentPanVal[1]].postln;
						});
					}.value;
				);


				~mDen = PopUpMenu();
				~mDen.items = Array.fill((~densityType.size - 1), {|i| ~densityType[i]});
				~stateDen = 0;

				~sDev = Array.fill(~currentDev.size, { |i|
					var min = 0.01, max = 1.0;
					RangeSlider()
					.lo_(~mapToSlider.(~currentDev[i][0], min, max))
					.hi_(~mapToSlider.(~currentDev[i][1], min, max))
					.orientation_(\horizontal)
					.knobColor_(Color.gray(0.5))
					.background_(~color[0])
					.action_({ |slider|

						~currentDev[i][0] = ~mapFromSlider.(slider.lo, min, max).round(0.01);

						~cueSpace[0].size.do{|n|
							if(~cueSpace[0][~cue][3] == "low", {
								~cueSpace[0][n][2][0] = ~currentDev[0][0];
							}, {

								if(~cueSpace[0][~cue][3] == "medium", {
									~cueSpace[0][n][2][0] = ~currentDev[1][0];
								});

								~cueSpace[0][n][2][0] = ~currentDev[2][0];

							});
						};

						~currentDev[i][1] = ~mapFromSlider.(slider.hi, min, max).round(0.01);

						~cueSpace[0].size.do{|n|
							if(~cueSpace[0][~cue][3] == "low", {
								~cueSpace[0][n][2][0] = ~currentDev[0][1];
							}, {

								if(~cueSpace[0][~cue][3] == "medium", {
									~cueSpace[0][n][2][0] = ~currentDev[1][1];
								});

								~cueSpace[0][n][2][0] = ~currentDev[2][1];

							});
						};

						 ~currentDev = ~currentDev.collect { |arr| arr.copy };

						[\devIndex, i, \low, ~currentDev[i][0], \hi, ~currentDev[i][1]].postln;
					})
				});


				~sProx = Array.fill(~currentProximity.size, { |i|
					var min = 0.1, max = 14.0;
					RangeSlider()
					.lo_(~mapToSlider.(~currentProximity[i][0], min, max))
					.hi_(~mapToSlider.(~currentProximity[i][1], min, max))
					.orientation_(\horizontal)
					.knobColor_(Color.gray(0.5))
					.background_(~color[0])
					.action_({ |slider|
						~currentProximity[i][0] = ~mapFromSlider.(slider.lo, min, max).round(0.01);

						~cueSpace[0].size.do{|n|
							if(~cueSpace[0][~cue][3] == "low", {
								~cueSpace[0][n][1][0] = ~currentProximity[0][0];
							}, {

								if(~cueSpace[0][~cue][3] == "medium", {
									~cueSpace[0][n][1][0] = ~currentProximity[1][0];
								});

								~cueSpace[0][n][1][0] = ~currentProximity[2][0];

							});
						};

						~currentProximity[i][1] = ~mapFromSlider.(slider.hi, min, max).round(0.01);

						~cueSpace[0].size.do{|n|
							if(~cueSpace[0][~cue][3] == "low", {
								~cueSpace[0][n][1][0] = ~currentProximity[0][1];
							}, {

								if(~cueSpace[0][~cue][3] == "medium", {
									~cueSpace[0][n][1][0] = ~currentProximity[1][1];
								});

								~cueSpace[0][n][1][0] = ~currentProximity[2][1];

							});
						};

						~currentProximity = ~currentProximity.collect { |arr| arr.copy };

						[\devIndex, i, \low, ~currentProximity[i][0], \hi, ~currentProximity[i][1]].postln;
					})
				});

				~sliderGroups = Array.fill(~currentDev.size, { |i| [~sDev[i], ~sProx[i]] });

				~updateSlidersForState = { |state|
					~sliderGroups.do { |group, i|
						group.do { |slider|
							slider.visible_(i == state);
						};
					};
				};

				~mDen.action = { |m|
					~stateDen = m.value;
					("Density state switched to: " + m.value).postln;
					~updateSlidersForState.(~stateDen);
				};


				(
					~checkGlobalVal = Task{
						{

							{
								if(g.isClosed.not) {
									~globalNum[0].string = "min: " ++ ~currentAmpVal[0];
									~globalNum[1].string = "max: " ++ ~currentAmpVal[1];
									~globalNum[2].string = "min: " ++ ~currentPanVal[0];
									~globalNum[3].string = "max: " ++ ~currentPanVal[1];
									~globalNum[4].string = "min: " ++ ~currentDev[~stateDen][0];
									~globalNum[5].string = "max: " ++ ~currentDev[~stateDen][1];
									~globalNum[6].string = "min: " ++ ~currentProximity[~stateDen][0];
									~globalNum[7].string = "max: " ++ ~currentProximity[~stateDen][1];
								}
							}.defer;

							0.1.wait;
						}.loop
					}.play;
				);

				(
					g = Window(
						"global variables",
						Rect(
							Window.screenBounds.width / 2 + 250,
							Window.screenBounds.height / 2 - 150,
							500,
							300
						)
					)
				)
				.alwaysOnTop_(true)
				.onClose_({~checkGlobalVal.stop; a.value = 0})
				.front
				.layout_(
					VLayout(
						~globalText[0],
						~globalText[1],
						~sAmp,
						HLayout(~globalNum[0], ~globalNum[1]),
						~globalText[2], ~sPan,
						HLayout(~globalNum[2], ~globalNum[3]),
						~globalText[2],
						~globalText[3],
						~mDen,
						~globalText[4],
						~sDev[0],
						~sDev[1],
						~sDev[2],
						HLayout(~globalNum[4], ~globalNum[5]),
						~globalText[5],
						~sProx[0],
						~sProx[1],
						~sProx[2],
						HLayout(~globalNum[6], ~globalNum[7]),
						~resetGlobalButton
				));

				~updateSlidersForState.(0); // Start with first set visible


			},{
				if(g.isClosed.not == true, {g.close;},{"error closing window".postln});
			});

		});



		//////////////////////////////////////////////////////////////////////////////////////////////////////
		// key configuartion button

		~keyConfButton = Button()
		.states_([
			["key configuration", ~color[3]],
			["close key configuration", ~color[6]]
		]);
/*
		~forwardBtn = 121;
		~backwardBtn = 116;*/

		~keyCheck = r { |inval|
			(~keyText[1].string = "press forward button once");
			~keyText[1].stringColor_(~color[3]).background_(~color[1]);
			~forwardBtn = inval.yield;
			postln([~forwardBtn]);
			(~keyText[1].string = "press backward button once");
			~keyText[1].stringColor_(~color[3]).background_(~color[2]);
			~backwardBtn = inval.yield;

			while { ~backwardBtn == ~forwardBtn } {
				~keyText[1].string = "choose a DIFFERENT backward button";
				~keyText[1].stringColor_(~color[3]).background_(~color[6]);
				~backwardBtn = inval.yield;
			};

			postln([~backwardBtn]);
			~keyText[1].stringColor_(~color[3]).background_(~color[7]);
			(~keyText[1].string = "press any button to close").yield;
			~wKey.close;
		};


		~keyConfButton.action_({ |a|
			if(a.value == 1, {

				~keyCheck.reset;

				~keyNum = Array.fill(2, {|i| StaticText()});
				~keyNum[0].string = ~forwardBtn;
				~keyNum[1].string = ~backwardBtn;

				~keyText = Array.fill(4, {|i| StaticText()});
				~keyText[0].string = "Follow the instructions to calibrate cue buttoons on your keyboard or pedal. If no change is needed, close the window without pressing a new button.";
				~keyText[1].string = "press any key to start the calibration process";
				~keyText[2].string = "Current forwards button";
				~keyText[3].string = "Current backwards button";

				~keyText[1].background_(~color[4]).stringColor_(~color[3]).align_(\center);
				~keyText[2].background_(~color[1]);
				~keyNum[0].background_(~color[3]).stringColor_(~color[4]).align_(\center);
				~keyText[3].background_(~color[2]);
				~keyNum[1].background_(~color[3]).stringColor_(~color[4]).align_(\center);


				~wKey = Window("key check")
				.layout_(VLayout(~keyText[0], ~keyText[1], HLayout(~keyText[2], ~keyNum[0], ~keyText[3], ~keyNum[1])))
				.onClose_({a.value = 0})
				.alwaysOnTop_(true)
				.front;

				(
					~checkKeyVal = Task{
						{

							{
								if(~wKey.isClosed.not) {
									~keyText[1];
									~keyNum[0].string = ~forwardBtn;
									~keyNum[1].string = ~backwardBtn;
								}
							}.defer;

							0.1.wait;
						}.loop
					}.play;
				);


				~wKey.view.keyDownAction = ({
					// the args must stay in this order to be properly read
					|view, char, modifiers, unicode, keycode|

					~keyCheck.next(keycode);
				});
			},{
				if(~wKey.isClosed.not == true, {~wKey.close;},{"error closing window".postln});
			});

		});

		~text = StaticText().string_("[?]").align_(\right);
		~exp = Array.fill(7, {\nil});
		~exp[0] = "cue number (for cue 0 density =  silent is recomended, so that the playback starts on the first press of forward button)";
		~exp[1] = "'-' removes the current cue and shortens the cue list by 1; '+' adds a new blank cue after the current cue and extends the cue list by 1";
		~exp[2] = "sample list by name – set of samples used in the cue in the format '1c, 2c, drone3', '-' is an empty list;";
		~exp[3] = "save button - for the new list to be updated; ";
		~exp[4] = "denisty menu – select the denisty type for the cue, IMPORTANT: if the cue is meant to be silent, select 'silent' from the menu";
		~exp[5] = "sample list – select and listen to the samples in the sample bank, use cmd+click to drag and drop a sample and add it to the sample list";
		~exp[6] = "global variables – influences the sound parameters for the whole preset";

		~text.setContextMenuActions(
			MenuAction(~exp[0]),
			MenuAction(~exp[1]),
			MenuAction(~exp[2]),
			MenuAction(~exp[3]),
			MenuAction(~exp[4]),
			MenuAction(~exp[5]),
			MenuAction(~exp[6]);
		);


		~menu = PopUpMenu();
		~currentCueArray = Array.fill(~cueNum, {|i| i});
		~menu.items = ~currentCueArray;

		~menu.action = ({ |menu|
			~cue = menu.value;
			~currentCueArray[menu.value].postln;
			~tTone.string = ~toneName[~cue].asString;

			~tone_list[~cue] = ~toneName[~cue];
			~formatToneList.value;
			~makeToneList.value;
			~densityType.size.do({|i|
				if(~cueSpace[0][~cue][3] == ~densityType[i], {
					~mDensity.value = i;
				});
			});
		});


		~buttonPlay.action_({ |butt|
			if(butt.value == 1,{
				t.play;
				~limitSynth = Synth(\limit);


				~cueText = StaticText()
				.string_("current cue")
				.background_(Color.blue)
				.stringColor_(Color.yellow)
				.font_(Font("Arial", 30))
				.align_(\center);
				~sampleText = StaticText()
				.string_("current samples")
				.background_(Color.blue)
				.stringColor_(Color.yellow)
				.font_(Font("Arial", 30))
				.align_(\center);
				~densityText = StaticText()
				.string_("density")
				.background_(Color.blue)
				.stringColor_(Color.yellow)
				.font_(Font("Arial", 30))
				.align_(\center);

				(
					r = Task {
						{

							{
								if(~wP.isClosed.not) {
									~cueText.string = ~cue.asString;
									~sampleText.string = ~tone_list[~cue].asString;
									~densityText.string = ~density[~cue][3].asString;
								}
							}.defer;

							0.1.wait;
						}.loop

					}.play;
				);

				~wP = Window(
					"perform",
					Rect(
						Window.screenBounds.width / 2 - 300,
						Window.screenBounds.height / 2 - 300,
						600,
						600
					)
				)
				.alwaysOnTop_(true)
				.onClose_({s.freeAll; t.stop; ~buttonPlay.value = 0;})
				.layout_(VLayout(~cueText, ~sampleText, ~densityText))
				.front;



				~wP.view.keyDownAction = ({
					// the args must stay in this order to be properly read
					|view, char, modifiers, unicode, keycode|
					if(keycode == ~forwardBtn,
						{postln(["up"]);
							~current = (~current+1).clip(0,~cueSpace[0].size - 1);
							~cue = ~current;
							postln(["cue: ", ~cue]);
							~tone_list[~cue].postln;
							postln(["density: ", ~density[~cue][3]]);
							~menu.value_(~current);
						},
						{
							if(keycode == ~backwardBtn,
								{postln(["down"]);
									~current = (~current-1).clip(0,~cueSpace[0].size);
									~cue = ~current;
									postln(["cue: ", ~cue]);
									~tone_list[~cue].postln;
									postln(["density: ", ~density[~cue][3]]);
									~menu.value_(~current);
								},
								{postln(["invalid"])}
							);
						}
					);
				});



			},{
				t.stop;
				s.freeAll;
				~wP.close;
			});
		});



		///////////////////////////////////////////////////////////////////////////////////////////////////
		// cue buttons

		// ====================================================================
		// ADD BUTTON  (fixed, safe, consistent arrays)
		// ====================================================================
		~addButton = Button().states_([["+", Color.black]]);

		~addButton.action_({
			var newCueIndex;

			// advance cue index
			newCueIndex = ~cue + 1;

			// ------------------------------
			// Insert NEW CUE at newCueIndex
			// ------------------------------
			~cueSpace[0] = ~cueSpace[0].insert(newCueIndex, ~pause.copy);
			~cueSpace[1] = ~cueSpace[1].insert(newCueIndex, [~silent]);
			~toneName    = ~toneName.insert(newCueIndex, "-");

			// Update cue index
			~cue = newCueIndex.clip(0, ~cueSpace[0].size - 1);

			// Rebuild cue index array
			~currentCueArray = Array.series(~cueSpace[0].size, 0, 1);

			// Update menu
			~menu.items = ~currentCueArray;
			~menu.value = ~cue;

			// Update tone text
			~tTone.string = ~toneName[~cue];

			// ----------------------------
			// Properly rebuild tone_list
			// ----------------------------
			~tone_list = ~toneName.copy;

			// Format tone list
			~formatToneList.value;
			~makeToneList.value;

			// update density display (pause index = 3)
			~mDensity.value = 3;

			~cueNum = ~currentCueArray.size;

			("Added cue at index " ++ ~cue).postln;
		});


		// ====================================================================
		// TAKE BUTTON (fixed, safe, consistent arrays)
		// ====================================================================
		~takeButton = Button().states_([["-", Color.black]]);

		~takeButton.action_({
			if (~cue == 0) {
				"first cue, cannot remove".postln;
				^nil;
			};

			// Remove arrays at current index
			~cueSpace[0].removeAt(~cue);
			~cueSpace[1].removeAt(~cue);
			~toneName.removeAt(~cue);

			// Move cue pointer back
			~cue = (~cue - 1).clip(0, ~cueSpace[0].size - 1);

			// Rebuild cue index array
			~currentCueArray = Array.series(~cueSpace[0].size, 0, 1);

			// Update GUI
			~menu.items = ~currentCueArray;
			~menu.value = ~cue;

			~tTone.string = ~toneName[~cue];

			// Rebuild tone_list safely
			~tone_list = ~toneName.copy;

			// formatting callbacks
			~formatToneList.value;
			~makeToneList.value;

			~cueNum = ~currentCueArray.size;

			("Removed cue, now at " ++ ~cue).postln;
		});


		// ====================================================================
		// DENSITY MENU (fixed mapping & safe write)
		// ====================================================================
		~mDensity = PopUpMenu().items_(~densityType);

		~mDensity.action = { |menu|
			var idx = menu.value;
			var densityList = [ ~low, ~medium, ~high, ~pause ];

			~cueSpace[0][~cue] = densityList[idx].copy; // store fresh independent copy

			("Set density for cue " ++ ~cue ++ " → " ++ densityList[idx][3]).postln;
		};




		///////////////////////////////////////////////////////////////////////////////////////////////////
		// list buttton

		~listButton = Button()
		.states_([
			["open sample list", Color.black],
			["close sample list", Color.red]
		]);



		~listButton.action_({ |a|

			if(a.value == 1, {

				(
					~menuList = ListView()
					.items_(~sampleList)
					.background_(Color.clear)
					.hiliteColor_(Color.green(alpha: 0.6))
					.selectionMode_(\single)
					.action_({ |sbs|
						[~selectedSample = sbs.selection, ~menuList.items[sbs.selection]].postln; // .value returns the integer
					});
				);


				~menuList.beginDragAction_({ |view|
					var sel = view.value;
					~menuList.items[sel].asString;
				});

				~sampleButton = Button()
				.states_([
					["play selected sample", Color.green, Color.gray(0.8)],
					["stop current sample", Color.red, Color.gray(0.8)]
				]);

				~sampleButton.action_({|a|
					a.value.postln;
					if(a.value == 1, {
						~playbackSynth = Synth(\playback, [\bufnum, ~buf[~selectedSample], \loop, 1, \amp, 1.0, \pan, 0.0]);
						~limitSynth = Synth(\limit);
						z = Task{
							{|current|
								~playbackSynth.set(\bufnum, ~buf[~selectedSample]);
								current = ~selectedSample;
								0.1.wait;
								if (~selectedSample != current, {~playbackSynth.set(\trig, 1)}, {~playbackSynth.set(\trig, 0)});
							}.loop;
						};
						z.play;
					},{
						z.stop;
						s.freeAll;
					});
				});

				l = Window(
					"List",
					Rect(
						Window.screenBounds.width - 500,
						Window.screenBounds.height - 400,
						500,
						400
					)
				)
				.front
				.onClose_({s.freeAll; a.value = 0})
				.alwaysOnTop_(true)
				.layout_(VLayout(~menuList, ~sampleButton));
			},{
				if(l.isClosed.not == true, {l.close;},{"error closing window".postln});
			});

		});

		~tTone = TextField();
		~tTone.string = "-";
		~tTone.action = { |view|
			~toneName[~cue] = view.string;
			/*	~tTone.valueAction_(~toneName[~current]);*/
		};
		~tTone.receiveDragHandler_({ |view|
			var old = view.string.trim;
			var newItem = ~menuList.items[~menuList.value].asString.trim;

			if (old.isEmpty) {
				view.string = newItem;
			} {
				view.string = old ++ ", " ++ newItem;
				~toneName[~cue] = view.string;
				~tTone.valueAction_(~toneName[~cue]);
			};
		});

		~writeButton = Button()
		.states_([["save list"]]);
		~writeButton.action_({
			~toneName[~cue] = ~tTone.value;
			~tone_list[~cue] = ~toneName[~cue];
			~formatToneList.value;
			~makeToneList.value;
		});



		~saveButton = Button()
		.states_([["save preset"]]);



		~saveButton.action_({
			(
				FileDialog({ |path|
					[
						~tone_list,
						~toneName,
						~sampleList,
						~proximity,
						~deviation,
						~density,
						~amp,
						~pan,
						~currentCueArray,
						~forwardBtn,
						~backwardBtn,
						~cueSpace,
						~cueNum
					].writeArchive(path);

					~currentPath = path;
					~tPreset.string = ~currentPath.asString;

						Window.closeAll;
						s.reboot;
						s.doWhenBooted({~func.value;});
					},
				fileMode: 0,
				acceptMode: 1,
				stripResult: true,
				path: ~path ++ "/presets");
			);
			"saved".postln;
		});

		~loadButton = Button()
		.states_([["load preset"]]);

		~loadButton.action_({
			(
				FileDialog({ |path|
					~reader = Object.readArchive(path);
					~reader.postln;
					~tTone.string = ~toneName[~current];
					~tPreset.string = path.basename.asString;
					postln("Selected file:" + path);
					postln("File type is:" + File.type(path));
					~currentPath = path;
					~tPreset.string = ~currentPath.asString;

						Window.closeAll;
						s.reboot;
						s.doWhenBooted({~func.value;});

				},
				fileMode: 0,
				acceptMode: 0,
				stripResult: true,
				path: ~path ++ "/presets");
			);
			"retrieved".postln;
		});


		~tPreset = StaticText()
		.background_(~color[4])
		.stringColor_(~color[3])
		.align_(\center);

		~tPreset.string = ~currentPath.asString;

		~seperator = Array.fill(4, {StaticText()});
		~seperator[0].string = "/edit cue/---------------------------";
		~seperator[1].string = "/play/---------------------------";
		~seperator[2].string = "---------------------------/save & load presets/---------------------------";
		~seperator[3].string = "---------------------------/edit play keys/---------------------------";
		~seperator.size.do{|i|
			~seperator[i].stringColor_(~color[0]).align_(\center);
		};
		~seperator[0].align_(\left);
		~seperator[1].align_(\left);


		~help = StaticText().string_("[?]").align_(\right);
		~help.setContextMenuActions(
			MenuAction("the cursor needs to be focused on the play window for the backwards and forwards buttons to work")
		);

		(
			~wM = Window(
				"compos mentis",
				Rect(
					Window.screenBounds.width / 2 - 250,
					Window.screenBounds.height / 2 - 150,
					500,
					300
				)
			)
		)
		.alwaysOnTop_(true)
		.onClose_({~checkGlobalVal.reset; ~checkGlobalVal.stop;
			s.freeAll;})
		.front
		.layout_(
			VLayout(
				~seperator[2],
				~tPreset,
				HLayout(~loadButton, ~saveButton),
				HLayout(~seperator[1],~help),
				~buttonPlay,
				HLayout(~seperator[0], ~text),
				~menu,
				HLayout(~takeButton, ~addButton),
				HLayout(~tTone, ~writeButton, ~mDensity),
				HLayout(~listButton),
				HLayout(~globalVarButton),
				~seperator[3],
				~keyConfButton

		));

	);
	};
	~func.value;
};
);
);
