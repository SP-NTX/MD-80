# McDonnell Douglas MD-80 PFD
# Copyright (c) 2021 Josh Davidson (Octal450)

var pfd1Display = nil;
var pfd2Display = nil;
var pfd1 = nil;
var pfd1Error = nil;
var pfd2 = nil;
var pfd2Error = nil;

var Value = {
	Ai: {
		pitch: 0,
		roll: 0,
	},
	Nav: {
		Freq: {
			selected: [0, 0],
			selectedInteger: [0, 0],
			selectedDecimal: [0, 0],
		},
		gsInRange: [0, 0],
		inRange: [0, 0],
		signalQuality: [0, 0],
	},
	Ra: {
		agl: 0,
	},
};

var canvasBase = {
	init: func(canvasGroup, file) {
		var font_mapper = func(family, weight) {
			return "LiberationFonts/LiberationSans-Regular.ttf";
		};
		
		canvas.parsesvg(canvasGroup, file, {"font-mapper": font_mapper});
		
		var svgKeys = me.getKeys();
		foreach(var key; svgKeys) {
			me[key] = canvasGroup.getElementById(key);
			
			var clip_el = canvasGroup.getElementById(key ~ "_clip");
			if (clip_el != nil) {
				clip_el.setVisible(0);
				var tranRect = clip_el.getTransformedBounds();
				
				var clip_rect = sprintf("rect(%d, %d, %d, %d)", 
					tranRect[1], # 0 ys
					tranRect[2], # 1 xe
					tranRect[3], # 2 ye
					tranRect[0] # 3 xs
				);
				
				# Coordinates are top, right, bottom, left (ys, xe, ye, xs) ref: l621 of simgear/canvas/CanvasElement.cxx
				me[key].set("clip", clip_rect);
				me[key].set("clip-frame", canvas.Element.PARENT);
			}
		}
		
		me.aiBackgroundTrans = me["AI_background"].createTransform();
		me.aiBackgroundRot = me["AI_background"].createTransform();
		
		me.aiScaleTrans = me["AI_scale"].createTransform();
		me.aiScaleRot = me["AI_scale"].createTransform();
		
		me.page = canvasGroup;
		
		return me;
	},
	getKeys: func() {
		return ["AI_center", "AI_background", "AI_scale", "AI_bank", "FD_pitch", "FD_roll", "ILS_group", "LOC_pointer", "LOC_scale", "LOC_no", "GS_pointer", "GS_scale", "GS_no", "FS_scale", "FS_pointer", "RA_bars", "RA_scale"];
	},
	setup: func() {
		# Hide the pages by default
		pfd1.page.hide();
		pfd1Error.page.hide();
		pfd2.page.hide();
		pfd2Error.page.hide();
	},
	update: func() {
		if (systems.DUController.updatePfd1) {
			pfd1.update();
		}
		if (systems.DUController.updatePfd2) {
			pfd2.update();
		}
	},
	updateBase: func() {
		# Fast Slow
		if (dfgs.Fma.thrA.getValue() == "RETD") {
			me["FS_scale"].hide();
		} else {
			me["FS_pointer"].setTranslation(0, pts.Instrumentation.Pfd.fastSlow.getValue() * 13.1);
			me["FS_scale"].show();
		}
		
		# AI
		Value.Ai.pitch = pts.Orientation.pitchDeg.getValue();
		Value.Ai.roll = pts.Orientation.rollDeg.getValue();
		
		AICenter = me["AI_center"].getCenter();
		
		me.aiBackgroundTrans.setTranslation(0, math.clamp(Value.Ai.pitch * 12.345, -240, 240)); # According to a pilot, it don't go the whole way
		me.aiBackgroundRot.setRotation(-Value.Ai.roll * D2R, AICenter);
		
		me.aiScaleTrans.setTranslation(0, Value.Ai.pitch * 12.345);
		me.aiScaleRot.setRotation(-Value.Ai.roll * D2R, AICenter);
		
		me["AI_bank"].setRotation(-Value.Ai.roll * D2R);
		
		# RA
		Value.Ra.agl = pts.Position.gearAglFt.getValue();
		if (Value.Ra.agl <= 3000) {
			me["RA_bars"].show();
			me["RA_scale"].setTranslation(0, math.clamp(Value.Ra.agl, 0, 3100) * 2.079);
			me["RA_scale"].show();
		} else {
			me["RA_bars"].hide();
			me["RA_scale"].hide();
		}
	},
};

var canvasPfd1 = {
	new: func(canvasGroup, file) {
		var m = {parents: [canvasPfd1, canvasBase]};
		m.init(canvasGroup, file);
		
		return m;
	},
	update: func() {
		if (dfgs.Output.fd1.getBoolValue()) {
			me["FD_pitch"].show();
			me["FD_roll"].show();
			
			me["FD_pitch"].setTranslation(0, -dfgs.Fd.pitchBar.getValue() * 4.3);
			me["FD_roll"].setTranslation(dfgs.Fd.rollBar.getValue() * 2.6, 0);
		} else {
			me["FD_pitch"].hide();
			me["FD_roll"].hide();
		}
		
		# ILS
		Value.Nav.Freq.selected[0] = pts.Instrumentation.Nav.Frequencies.selectedMhzFmtX100[0].getValue();
		Value.Nav.Freq.selectedDecimal[0] = right("" ~ Value.Nav.Freq.selected[0], 2);
		Value.Nav.Freq.selectedInteger[0] = math.floor(Value.Nav.Freq.selected[0]);
		
		if (Value.Nav.Freq.selectedInteger[0] < 11200 and (Value.Nav.Freq.selectedDecimal[0] == 10 or Value.Nav.Freq.selectedDecimal[0] == 15 or Value.Nav.Freq.selectedDecimal[0] == 30 or Value.Nav.Freq.selectedDecimal[0] == 35 or Value.Nav.Freq.selectedDecimal[0] == 50 or Value.Nav.Freq.selectedDecimal[0] == 55 or Value.Nav.Freq.selectedDecimal[0] == 70 or Value.Nav.Freq.selectedDecimal[0] == 75 or Value.Nav.Freq.selectedDecimal[0] == 90 or Value.Nav.Freq.selectedDecimal[0] == 95)) {
			me["ILS_group"].show();
		} else {
			me["ILS_group"].hide();
		}
		
		Value.Nav.inRange[0] = pts.Instrumentation.Nav.inRange[0].getBoolValue();
		Value.Nav.signalQuality[0] = pts.Instrumentation.Nav.signalQualityNorm[0].getValue();
		if (Value.Nav.inRange[0] and Value.Nav.signalQuality[0] > 0.99) {
			me["LOC_pointer"].show();
			me["LOC_pointer"].setTranslation(pts.Instrumentation.Nav.headingNeedleDeflectionNorm[0].getValue() * 156, 0);
			me["LOC_no"].hide();
			me["LOC_scale"].show();
		} else {
			me["LOC_pointer"].hide();
			me["LOC_no"].show();
			me["LOC_scale"].hide();
		}
		
		Value.Nav.gsInRange[0] = pts.Instrumentation.Nav.gsInRange[0].getBoolValue();
		if (Value.Nav.gsInRange[0] and Value.Nav.signalQuality[0] > 0.99 and pts.Instrumentation.Nav.hasGs[0].getBoolValue()) {
			me["GS_pointer"].show();
			me["GS_pointer"].setTranslation(0, pts.Instrumentation.Nav.gsNeedleDeflectionNorm[0].getValue() * -148);
			me["GS_no"].hide();
			me["GS_scale"].show();
		} else {
			me["GS_pointer"].hide();
			me["GS_no"].show();
			me["GS_scale"].hide();
		}
		
		me.updateBase();
	},
};

var canvasPfd2 = {
	new: func(canvasGroup, file) {
		var m = {parents: [canvasPfd2, canvasBase]};
		m.init(canvasGroup, file);
		
		return m;
	},
	update: func() {
		if (dfgs.Output.fd2.getBoolValue()) {
			me["FD_pitch"].show();
			me["FD_roll"].show();
			
			me["FD_pitch"].setTranslation(0, -dfgs.Fd.pitchBar.getValue() * 4.3);
			me["FD_roll"].setTranslation(dfgs.Fd.rollBar.getValue() * 2.6, 0);
		} else {
			me["FD_pitch"].hide();
			me["FD_roll"].hide();
		}
		
		# ILS
		Value.Nav.Freq.selected[1] = pts.Instrumentation.Nav.Frequencies.selectedMhzFmtX100[1].getValue();
		Value.Nav.Freq.selectedDecimal[1] = right("" ~ Value.Nav.Freq.selected[1], 2);
		Value.Nav.Freq.selectedInteger[1] = math.floor(Value.Nav.Freq.selected[1]);
		
		if (Value.Nav.Freq.selectedInteger[1] < 11200 and (Value.Nav.Freq.selectedDecimal[1] == 10 or Value.Nav.Freq.selectedDecimal[1] == 15 or Value.Nav.Freq.selectedDecimal[1] == 30 or Value.Nav.Freq.selectedDecimal[1] == 35 or Value.Nav.Freq.selectedDecimal[1] == 50 or Value.Nav.Freq.selectedDecimal[1] == 55 or Value.Nav.Freq.selectedDecimal[1] == 70 or Value.Nav.Freq.selectedDecimal[1] == 75 or Value.Nav.Freq.selectedDecimal[1] == 90 or Value.Nav.Freq.selectedDecimal[1] == 95)) {
			me["ILS_group"].show();
		} else {
			me["ILS_group"].hide();
		}
		
		Value.Nav.inRange[1] = pts.Instrumentation.Nav.inRange[1].getBoolValue();
		Value.Nav.signalQuality[1] = pts.Instrumentation.Nav.signalQualityNorm[1].getValue();
		if (Value.Nav.inRange[1] and Value.Nav.signalQuality[1] > 0.99) {
			me["LOC_pointer"].show();
			me["LOC_pointer"].setTranslation(pts.Instrumentation.Nav.headingNeedleDeflectionNorm[1].getValue() * 156, 0);
			me["LOC_no"].hide();
			me["LOC_scale"].show();
		} else {
			me["LOC_pointer"].hide();
			me["LOC_no"].show();
			me["LOC_scale"].hide();
		}
		
		Value.Nav.gsInRange[1] = pts.Instrumentation.Nav.gsInRange[1].getBoolValue();
		if (Value.Nav.gsInRange[1] and Value.Nav.signalQuality[1] > 0.99 and pts.Instrumentation.Nav.hasGs[1].getBoolValue()) {
			me["GS_pointer"].show();
			me["GS_pointer"].setTranslation(0, pts.Instrumentation.Nav.gsNeedleDeflectionNorm[1].getValue() * -148);
			me["GS_no"].hide();
			me["GS_scale"].show();
		} else {
			me["GS_pointer"].hide();
			me["GS_no"].show();
			me["GS_scale"].hide();
		}
		
		me.updateBase();
	},
};

var canvasPfd1Error = {
	init: func(canvasGroup, file) {
		var font_mapper = func(family, weight) {
			return "LiberationFonts/LiberationSans-Regular.ttf";
		};
		
		canvas.parsesvg(canvasGroup, file, {"font-mapper": font_mapper});
		
		var svgKeys = me.getKeys();
		foreach(var key; svgKeys) {
			me[key] = canvasGroup.getElementById(key);
		}
		
		me.page = canvasGroup;
		
		return me;
	},
	new: func(canvasGroup, file) {
		var m = {parents: [canvasPfd1Error]};
		m.init(canvasGroup, file);
		
		return m;
	},
	getKeys: func() {
		return ["Error_Code"];
	},
	update: func() {
		me["Error_Code"].setText(acconfig.SYSTEM.Error.code.getValue());
	},
};

var canvasPfd2Error = {
	init: func(canvasGroup, file) {
		var font_mapper = func(family, weight) {
			return "LiberationFonts/LiberationSans-Regular.ttf";
		};
		
		canvas.parsesvg(canvasGroup, file, {"font-mapper": font_mapper});
		
		var svgKeys = me.getKeys();
		foreach(var key; svgKeys) {
			me[key] = canvasGroup.getElementById(key);
		}
		
		me.page = canvasGroup;
		
		return me;
	},
	new: func(canvasGroup, file) {
		var m = {parents: [canvasPfd2Error]};
		m.init(canvasGroup, file);
		
		return m;
	},
	getKeys: func() {
		return ["Error_Code"];
	},
	update: func() {
		me["Error_Code"].setText(acconfig.SYSTEM.Error.code.getValue());
	},
};

var init = func() {
	pfd1Display = canvas.new({
		"name": "PFD1",
		"size": [1024, 800],
		"view": [1024, 800],
		"mipmapping": 1
	});
	pfd2Display = canvas.new({
		"name": "PFD2",
		"size": [1024, 800],
		"view": [1024, 800],
		"mipmapping": 1
	});
	
	pfd1Display.addPlacement({"node": "pfd1.screen"});
	pfd2Display.addPlacement({"node": "pfd2.screen"});
	
	var pfd1Group = pfd1Display.createGroup();
	var pfd1ErrorGroup = pfd1Display.createGroup();
	var pfd2Group = pfd2Display.createGroup();
	var pfd2ErrorGroup = pfd2Display.createGroup();
	
	pfd1 = canvasPfd1.new(pfd1Group, "Aircraft/MD-80/Models/Instruments/PFD/res/PFD.svg");
	pfd1Error = canvasPfd1Error.new(pfd1ErrorGroup, "Aircraft/MD-80/Models/Instruments/PFD/res/Error.svg");
	pfd2 = canvasPfd2.new(pfd2Group, "Aircraft/MD-80/Models/Instruments/PFD/res/PFD.svg");
	pfd2Error = canvasPfd2Error.new(pfd2ErrorGroup, "Aircraft/MD-80/Models/Instruments/PFD/res/Error.svg");
	
	canvasBase.setup();
	pfdUpdate.start();
	
	if (pts.Systems.Acconfig.Options.Du.pfdFps.getValue() != 20) {
		rateApply();
	}
}

var rateApply = func() {
	pfdUpdate.restart(1 / pts.Systems.Acconfig.Options.Du.pfdFps.getValue());
}

var pfdUpdate = maketimer(0.05, func() { # 20FPS
	canvasBase.update();
});

var showPfd1 = func() {
	var dlg = canvas.Window.new([256, 200], "dialog").set("resize", 1);
	dlg.setCanvas(pfd1Display);
	dlg.set("title", "Captain's PFD");
}

var showPfd2 = func() {
	var dlg = canvas.Window.new([256, 200], "dialog").set("resize", 1);
	dlg.setCanvas(pfd2Display);
	dlg.set("title", "First Officers's PFD");
}
