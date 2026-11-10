"use strict";
"require view";
"require form";
"require uci";

return view.extend({
	load: function() {
		return uci.load("istoreenhance");
	},

	render: function() {
		var m, s, o;

		m = new form.Map("istoreenhance", _("KSpeeder 缓存回收"),
			_("缓存超过阈值时自动清理；到达设定时间后由 cron 每 15 分钟轮询一次（精度 ≤15 分钟）。"));

		s = m.section(form.NamedSection, "@istoreenhance[0]", "istoreenhance", _("设置"));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, "gc_enabled", _("启用自动回收"));
		o.default = "1";
		o.rmempty = false;

		o = s.option(form.Value, "gc_limit_mb", _("缓存阈值 (MB)"),
			_("默认 2048（2 GiB）；只有超过该值才会清理，避免误删热缓存。"));
		o.datatype = "uinteger";
		o.placeholder = "2048";
		o.rmempty = false;

		o = s.option(form.Value, "gc_time", _("每天检查时间"),
			_("格式 HH:MM（24 小时制），默认 04:15。"));
		o.placeholder = "04:15";
		o.rmempty = false;
		o.validate = function(section_id, value) {
			if (!value)
				return true;
			return /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(value) ? true : _("格式应为 HH:MM，例如 04:15");
		};

		return m.render();
	}
});
