# Aircraft Config Center V2.0.0
# Copyright (c) 2023 Josh Davidson (Octal450)

var CONFIG = {
	minFgfs: split(".", getprop("/sim/minimum-fg-version")),
	minFgfsString: getprop("/sim/minimum-fg-version"),
	minOptionsRevision: 222, # Minimum revision of supported options
	noUpdateCheck: 0, # Disable ACCONFIG Update Checks
};

var SYSTEM = {
	autoConfigRunning: props.globals.getNode("/systems/acconfig/autoconfig-running"),
	Error: {
		active: props.globals.initNode("/systems/acconfig/error-active", 0, "BOOL"),
		outOfDate: 0,
		reason: props.globals.initNode("/systems/acconfig/error-reason", "", "STRING"),
	},
	fgfs: split(".", getprop("/sim/version/flightgear")),
	newRevision: props.globals.initNode("/systems/acconfig/new-revision", 0, "INT"),
	revision: props.globals.initNode("/systems/acconfig/revision", 0, "INT"),
	revisionTemp: 0,
	spinner: "\\",
	simInit: func() {
		PANEL.stop = 1;
		me.autoConfigRunning.setBoolValue(0);
		spinningT.start();
		fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-init"}));
		if (!CONFIG.noUpdateCheck) {
			http.load("https://raw.githubusercontent.com/Octal450/MD-80/master/revision.txt").done(func(r) me.newRevision.setValue(r.response));
		}
		me.revision.setValue(io.readfile(getprop("/sim/aircraft-dir") ~ "/revision.txt"));
		print("System: MD-80 Revision " ~ me.revision.getValue());
	},
	fdmInit: func() {
		me.revisionTemp = me.revision.getValue();
		
		if (!CONFIG.noUpdateCheck) {
			if (me.newRevision.getValue() > me.revisionTemp) {
				me.Error.outOfDate = 1;
				print("System: Aircraft update available!");
			} else {
				me.Error.outOfDate = 0;
				print("System: No aircraft update available!");
			}
		} else {
			print("System: Update checks have been turned off!");
		}
		
		fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-init"}));
		fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-init-gauge"}));
		OPTIONS.read();
		
		# Now lets let all the analog gauges go to the right place
		me.autoConfigRunning.setBoolValue(1);
	},
	finalInit: func() {
		settimer(func() {
			me.autoConfigRunning.setBoolValue(0);
			fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-init-gauge"}));
			spinningT.stop();
			me.errorCheck();
			
			if (!CONFIG.noUpdateCheck) { # Update Checks Enabled
				if (me.Error.outOfDate) {
					fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-update"}));
				} else if (!me.Error.active.getBoolValue()) {
					if (OPTIONS.savedRevision.getValue() < me.revisionTemp) {
						fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-updated"}));
					} else if (!OPTIONS.welcomeSkip.getBoolValue()) {
						fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-welcome"}));
					}
					
					# Only do on successful init
					RENDERING.check();
					OPTIONS.savedRevision.setValue(me.revisionTemp);
					OPTIONS.write();
				}
			} else { # No Update Checks
				if (!me.Error.active.getBoolValue()) {
					if (!OPTIONS.welcomeSkip.getBoolValue()) {
						fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-welcome"}));
					}
					
					# Only do on successful init
					RENDERING.check();
					OPTIONS.savedRevision.setValue(me.revisionTemp);
					OPTIONS.write();
				}
			}
		}, 5);
	},
	errorCheck: func() {
		if (!me.versionCheck()) {
			me.Error.active.setBoolValue(1);
			me.Error.reason.setValue("FGFS version is too old. Please update FlightGear to at least " ~ CONFIG.minFgfsString ~ ".");
			me.showError();
			print("System: FGVer Error");
		} else if (getprop("/gear/gear[0]/wow") == 0 or getprop("/position/altitude-ft") >= 15000) {
			me.Error.active.setBoolValue(1);
			me.Error.reason.setValue("Preposterous configuration detected for initialization. Check your position or scenery.");
			me.showError();
			print("System: Init Error");
		} else if (getprop("/systems/acconfig/libraries-loaded") != 1 or getprop("/systems/acconfig/property-tree-setup-loaded") != 1) {
			me.Error.active.setBoolValue(1);
			me.Error.reason.setValue("System files are missing or damaged. Please download a new copy of the aircraft.");
			me.showError();
			print("System: Files Error");
		}
	},
	resetFailures: func() {
		systems.ELEC.resetFailures();
		systems.FCTL.resetFailures();
		systems.FUEL.resetFailures();
		systems.GEAR.resetFailures();
		systems.HYD.resetFailures();
		systems.PNEU.resetFailures();
	},
	showError: func() {
		libraries.systemsLoop.stop();
		systems.DUController.showError();
		fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-updated"}));
		fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-welcome"}));
		fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-error"}));
		# Kill menu items
		setprop("/sim/menubar/default/menu[101]/enabled", 0);
		setprop("/sim/menubar/default/menu[102]/enabled", 0);
		setprop("/sim/menubar/default/menu[103]/enabled", 0);
		setprop("/sim/menubar/default/menu[104]/enabled", 0);
	},
	spinning: func() {
		if (me.spinner == "\\") {
			me.spinner = "|";
		} else if (me.spinner == "|") {
			me.spinner = "/";
		} else if (me.spinner == "/") {
			me.spinner = "-";
		} else if (me.spinner == "-") {
			me.spinner = "\\";
		}
		props.globals.getNode("/systems/acconfig/spinner-prop").setValue(me.spinner);
	},
	versionCheck: func() {
		if (SYSTEM.fgfs[0] < CONFIG.minFgfs[0] or SYSTEM.fgfs[1] < CONFIG.minFgfs[1]) {
			return 0;
		} else if (SYSTEM.fgfs[1] == CONFIG.minFgfs[1]) {
			if (SYSTEM.fgfs[2] < CONFIG.minFgfs[2]) {
				return 0;
			} else {
				return 1;
			}
		} else {
			return 1;
		}
	},
};

var RENDERING = {
	als: props.globals.getNode("/sim/rendering/shaders/skydome"),
	alsMode: props.globals.getNode("/sim/gui/dialogs/advanced/mode/als-mode", 1),
	customSettings: props.globals.getNode("/sim/rendering/shaders/custom-settings"),
	landmass: props.globals.getNode("/sim/rendering/shaders/landmass"),
	landmassSet: 0,
	lowSpecMode: props.globals.getNode("/sim/gui/dialogs/advanced/mode/low-spec-mode", 1),
	model: props.globals.getNode("/sim/rendering/shaders/model"),
	modelEffects: props.globals.getNode("/sim/gui/dialogs/advanced/model-effects", 1),
	modelSet: 0,
	rembrandt: props.globals.getNode("/sim/rendering/rembrandt/enabled"),
	check: func() {
		if (OPTIONS.noRenderingWarn.getBoolValue()) {
			return;
		}
		
		me.landmassSet = me.landmass.getValue() >= 4;
		me.modelSet = me.model.getValue() >= 3;
		
		if (SYSTEM.fgfs[0] >= 2020 and SYSTEM.fgfs[1] >= 4) {
			if (!me.rembrandt.getBoolValue() and (!me.als.getBoolValue() or !me.landmassSet or !me.modelSet)) {
				fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-rendering"}));
			}
		} else {
			if (!me.rembrandt.getBoolValue() and (!me.als.getBoolValue() or !me.customSettings.getBoolValue() or !me.landmassSet or !me.modelSet)) {
				fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-rendering"}));
			}
		}
	},
	fixAll: func() {
		# Don't override higher settings
		if (me.landmass.getValue() < 4) {
			me.landmass.setValue(4);
			if (SYSTEM.fgfs[0] >= 2020 and SYSTEM.fgfs[1] >= 4) {
				me.modelEffects.setValue("Medium");
			}
		}
		if (me.model.getValue() < 3) {
			me.model.setValue(3);
			if (SYSTEM.fgfs[0] >= 2020 and SYSTEM.fgfs[1] >= 4) {
				me.modelEffects.setValue("Enabled");
			}
		}
		
		me.fixCore();
	},
	fixCore: func() {
		me.als.setBoolValue(1); # ALS on
		if (SYSTEM.fgfs[0] >= 2020 and SYSTEM.fgfs[1] >= 4) {
			me.alsMode.setBoolValue(1);
			me.lowSpecMode.setBoolValue(0);
		} else {
			me.customSettings.setBoolValue(1);
		}
		
		print("System: Rendering Settings updated!");
		gui.popupTip("System: Rendering settings updated!");
	},
};

var OPTIONS = {
	noRenderingWarn: props.globals.initNode("/systems/acconfig/options/no-rendering-warn", 0, "BOOL"),
	savedRevision: props.globals.initNode("/systems/acconfig/options/saved-revision", 0, "INT"),
	tempRevision: props.globals.initNode("/systems/acconfig/temp/saved-revision", 0, "INT"),
	welcomeSkip: props.globals.initNode("/systems/acconfig/options/welcome-skip", 0, "BOOL"),
	read: func() {
		io.read_properties(getprop("/sim/fg-home") ~ "/Export/MD-80-options.xml", "/systems/acconfig/temp");
		
		# Only load if options is new enough
		if (me.tempRevision.getValue() < CONFIG.minOptionsRevision) {
			print("System: Options reset!");
			gui.popupTip("System: Aircraft Options have been reset due to aircraft installation/update!", 10);
		} else {
			io.read_properties(getprop("/sim/fg-home") ~ "/Export/MD-80-options.xml", "/systems/acconfig/options");
			
			# These aren't stored in acconfig themselves, so we move them there
			setprop("/sim/model/autopush/route/show", getprop("/systems/acconfig/options/autopush/show-route"));
			setprop("/sim/model/autopush/route/show-wingtip", getprop("/systems/acconfig/options/autopush/show-wingtip"));
			print("System: Options loaded successfully!");
		}
	},
	write: func() {
		# These aren't stored in acconfig themselves, so we move them there
		setprop("/systems/acconfig/options/autopush/show-route", getprop("/sim/model/autopush/route/show"));
		setprop("/systems/acconfig/options/autopush/show-wingtip", getprop("/sim/model/autopush/route/show-wingtip"));
		
		io.write_properties(getprop("/sim/fg-home") ~ "/Export/MD-80-options.xml", "/systems/acconfig/options");
	},
};

# Panel States specifically designed to work with IntegratedSystems design
var PANEL = {
	engTimer: 10,
	l1: nil,
	stop: 1,
	cancel: func() {
		me.stop = 1; # Kill timers
		
		# Kill listeners
		if (me.l1 != nil) {
			removelistener(me.l1);
			me.l1 = nil; # Important
		}
		
		me.panelBase(0, 1); # Don't disable stop
		
		pts.Services.Chocks.enable.setBoolValue(1);
		systems.ENGINE.cutoffSwitch[0].setBoolValue(1);
		systems.ENGINE.cutoffSwitch[1].setBoolValue(1);
		
		fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-psload"}));
		fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-init"}));
		
		settimer(func() { # Give things a moment to settle
			fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-init"}));
			spinningT.stop();
			SYSTEM.autoConfigRunning.setBoolValue(0);
		}, 4); # Let analog gauges go to the right place
	},
	panelBase: func(t, s = 0) {
		if (s != 1) {
			me.stop = 0;
		}
		
		SYSTEM.autoConfigRunning.setBoolValue(1);
		spinningT.start();
		fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-psloaded"}));
		fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-psload"}));
		systems.doIdleThrust();
		libraries.systemsInit();
		pts.Controls.Flight.speedbrake.setValue(0);
		if (t == 1) {
			pts.Controls.Flight.elevatorTrim.setValue(-0.26); # About 3.25ANU
			pts.Controls.Flight.flaps.setValue(0.36); # 11/MID
			pts.Controls.Flight.speedbrakeArm.setBoolValue(1);
		} else {
			pts.Controls.Flight.elevatorTrim.setValue(-0.26); # About 3.25ANU
			pts.Controls.Flight.flaps.setValue(0);
			pts.Controls.Flight.speedbrakeArm.setBoolValue(0);
		}
		systems.GEAR.Switch.leverCockpit.setValue(3);
	},
	coldDark: func(s = 0) {
		me.panelBase(0);
		
		pts.Services.Chocks.enable.setBoolValue(1);
		systems.ENGINE.cutoffSwitch[0].setBoolValue(1);
		systems.ENGINE.cutoffSwitch[1].setBoolValue(1);
		
		settimer(func() { # Give things a moment to settle
			fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-psload"}));
			spinningT.stop();
			if (!s) {
				fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-psloaded"}));
			}
			SYSTEM.autoConfigRunning.setBoolValue(0);
			me.stop = 1;
		}, 4); # Let analog gauges go to the right place
	},
	beforeStart: func() {
		me.panelBase(0);
		
		pts.Services.Chocks.enable.setBoolValue(1);
		systems.ELEC.Switch.battery.setBoolValue(1);
		systems.FUEL.Switch.pumpStart.setBoolValue(1);
		systems.APU.fastStart();
		pts.Controls.Lighting.beacon.setBoolValue(1);
		pts.Controls.Lighting.positionStrobeLight.setValue(0.5);
		pts.Controls.Switches.seatbeltSign.setBoolValue(1);
		
		systems.ENGINE.cutoffSwitch[0].setBoolValue(1);
		systems.ENGINE.cutoffSwitch[1].setBoolValue(1);
		
		me.l1 = setlistener("/engines/engine[2]/state", func() {
			if (systems.APU.state.getValue() == 3) {
				removelistener(me.l1);
				me.l1 = nil; # Important
				systems.ELEC.Switch.apuPwrL.setBoolValue(1);
				systems.ELEC.Switch.apuPwrR.setBoolValue(1);
				systems.FUEL.Switch.pumpAftL.setBoolValue(1);
				systems.FUEL.Switch.pumpAftR.setBoolValue(1);
				systems.FUEL.Switch.pumpFwdL.setBoolValue(1);
				systems.FUEL.Switch.pumpFwdR.setBoolValue(1);
				if (pts.Fdm.JSBsim.Propulsion.Tank.contentLbs[1].getValue() > 10) {
					systems.FUEL.Switch.pumpAftC.setBoolValue(1);
					systems.FUEL.Switch.pumpFwdC.setBoolValue(1);
				}
				systems.FUEL.Switch.pumpStart.setBoolValue(0);
				systems.PNEU.Switch.bleedApu.setValue(1);
				systems.PNEU.Switch.xBleedL.setValue(1);
				systems.PNEU.Switch.xBleedR.setValue(1);
				dfgs.Input.fd1.setBoolValue(1);
				dfgs.Input.fd2.setBoolValue(1);
				fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-psload"}));
				spinningT.stop();
				fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-psloaded"}));
				SYSTEM.autoConfigRunning.setBoolValue(0);
				me.stop = 1;
			}
		});
	},
	afterStart: func(t) {
		me.panelBase(t);
		
		pts.Services.Chocks.enable.setBoolValue(0);
		systems.ELEC.Switch.battery.setBoolValue(1);
		systems.ELEC.Switch.groundCart.setBoolValue(1); # autoConfigRunning cancels disable check in libraries.nas
		systems.ELEC.Switch.extPwrL.setBoolValue(1);
		systems.ELEC.Switch.extPwrR.setBoolValue(1);
		pts.Controls.Switches.seatbeltSign.setBoolValue(1);
		pts.Controls.Lighting.beacon.setBoolValue(1);
		pts.Controls.Lighting.positionStrobeLight.setValue(0.5);
		systems.FUEL.Switch.pumpAftL.setBoolValue(1);
		systems.FUEL.Switch.pumpAftR.setBoolValue(1);
		systems.FUEL.Switch.pumpFwdL.setBoolValue(1);
		systems.FUEL.Switch.pumpFwdR.setBoolValue(1);
		if (pts.Fdm.JSBsim.Propulsion.Tank.contentLbs[1].getValue() > 10) {
			systems.FUEL.Switch.pumpAftC.setBoolValue(1);
			systems.FUEL.Switch.pumpFwdC.setBoolValue(1);
		}
		systems.IGNITION.Switch.ign.setValue(1);
		systems.PNEU.Switch.supplyL.setValue(2);
		systems.PNEU.Switch.supplyR.setValue(2);
		systems.PNEU.Switch.xBleedL.setValue(1);
		systems.PNEU.Switch.xBleedL.setValue(1);
		systems.PNEU.Switch.xBleedR.setValue(1);
		
		if (pts.Engines.Engine.state[0].getValue() != 3 or pts.Engines.Engine.state[1].getValue() != 3) {
			engTimer = 10;
			settimer(func() {
				if (!me.stop) {
					systems.IGNITION.fastStart(0);
					systems.IGNITION.fastStart(1);
				}
			}, 0.5);
		} else {
			engTimer = 1;
		}
		
		me.l1 = setlistener("/engines/engine[1]/state", func() {
			if (pts.Engines.Engine.state[1].getValue() == 3) {
				removelistener(me.l1);
				me.l1 = nil; # Important
				systems.ELEC.Switch.groundCart.setBoolValue(0);
				systems.ELEC.Switch.extPwrL.setBoolValue(0);
				systems.ELEC.Switch.extPwrR.setBoolValue(0);
				systems.HYD.Switch.lPump.setValue(2);
				systems.HYD.Switch.rPump.setValue(2);
				systems.IGNITION.Switch.ign.setValue(0);
				systems.PNEU.Switch.xBleedL.setValue(0);
				systems.PNEU.Switch.xBleedR.setValue(0);
				# XPDR TA/RA
				dfgs.Input.fd1.setBoolValue(1);
				dfgs.Input.fd2.setBoolValue(1);
				
				if (t == 1) {
					pts.Controls.Lighting.positionStrobeLight.setValue(1);
					pts.Controls.Lighting.landingLightL.setValue(1);
					pts.Controls.Lighting.landingLightN.setValue(1);
					pts.Controls.Lighting.landingLightR.setValue(1);
				} else {
					pts.Controls.Lighting.landingLightL.setValue(0.5);
					pts.Controls.Lighting.landingLightN.setValue(0.5);
					pts.Controls.Lighting.landingLightR.setValue(0.5);
				}
				
				settimer(func() {
					if (!me.stop) {
						if (t == 1) {
							systems.BRAKES.Switch.abs.setValue(-1); # T/O
							systems.BRAKES.Switch.arm.setBoolValue(1);
							dfgs.Input.toga.setValue(1);
						}
					}
				}, 0.5);
				
				settimer(func() { # Give things a moment to settle
					if (!me.stop) {
						fgcommand("dialog-close", props.Node.new({"dialog-name": "acconfig-psload"}));
						spinningT.stop();
						fgcommand("dialog-show", props.Node.new({"dialog-name": "acconfig-psloaded"}));
						SYSTEM.autoConfigRunning.setBoolValue(0);
						me.stop = 1;
					}
				}, engTimer);
			}
		});
	},
};

var spinningT = maketimer(0.05, SYSTEM, SYSTEM.spinning);
SYSTEM.simInit();

setlistener("/sim/signals/reinit", func(s) {
	if (!s.getBoolValue() and libraries.initDone) {
		PANEL.coldDark(1);
	}
});
