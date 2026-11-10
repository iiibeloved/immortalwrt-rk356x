"use strict";
"require view";
"require fs";
"require ui";

return view.extend({
	handleSort: function(mode) {
		var self = this;
		return fs.exec('/usr/bin/luci-services-order', [ mode ]).then(function(res) {
			var out = (res && (res.stdout || res.stderr)) || '';
			ui.addNotification(null,
				E('div', {}, [
					E('p', {}, _('排序已完成（%s）').format(mode === 'reverse' ? _('反向') : _('正向'))),
					E('pre', { style: 'white-space:pre-wrap' }, out || _('无输出'))
				]),
				'info');

			/* 强制刷新当前页面（含浏览器缓存） */
			setTimeout(function() {
				try { location.reload(true); }
				catch(e) { location.href = location.href.split('#')[0]; }
			}, 800);
		}).catch(function(err) {
			ui.addNotification(null,
				E('p', {}, _('执行失败：%s').format(err && err.message ? err.message : err)),
				'danger');
		});
	},

	handleLog: function() {
		return fs.read('/etc/luci-services-order.log').then(function(data) {
			ui.showModal(_('排序日志'), [
				E('pre', { style: 'white-space:pre-wrap;max-height:60vh;overflow:auto' }, data || _('（空）')),
				E('div', { class: 'right' }, [
					E('button', { class: 'btn', click: ui.hideModal }, _('关闭'))
				])
			]);
		}).catch(function() {
			ui.addNotification(null, E('p', {}, _('日志读取失败或不存在')), 'warning');
		});
	},

	render: function() {
		return E('div', { class: 'cbi-map' }, [
			E('h2', {}, _('菜单排序')),
			E('div', { class: 'cbi-map-descr' }, [
				_('按规则重排「服务」菜单：英文名应用在前（A-Z），中文名应用在后（拼音首字母）。'),
				E('br'),
				_('注意：安装/升级应用后菜单顺序会被重置，可再次点击按钮一键修复。')
			]),
			E('div', { class: 'cbi-section' }, [
				E('button', {
					class: 'cbi-button cbi-button-apply',
					style: 'margin-right:8px',
					click: ui.createHandlerFn(this, function() { return this.handleSort('forward'); })
				}, _('正向排序（英文 A-Z → 中文拼音）')),
				E('button', {
					class: 'cbi-button cbi-button-reset',
					style: 'margin-right:8px',
					click: ui.createHandlerFn(this, function() { return this.handleSort('reverse'); })
				}, _('反向排序（中文倒序 → 英文倒序）')),
				E('button', {
					class: 'cbi-button',
					click: ui.createHandlerFn(this, function() { return this.handleLog(); })
				}, _('查看日志'))
			]),
			E('div', { class: 'cbi-section' }, [
				E('h3', {}, _('执行说明')),
				E('ul', {}, [
					E('li', {}, _('正向：DDNS-Go、Docker Manager… 之后的「中文名」按拼音首字母排列')),
					E('li', {}, _('反向：整体倒序（中文倒序在前，英文倒序在后）')),
					E('li', {}, _('执行完成后页面会自动强制刷新（Ctrl+F5 效果）')),
					E('li', {}, _('底层脚本：/usr/bin/luci-services-order；日志：/etc/luci-services-order.log'))
				])
			])
		]);
	}
});
