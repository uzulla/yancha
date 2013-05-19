/**
 * @fileOverview 未読セルの管理を行うスクリプト。後付なので、機能的には一部しか保持していない。
 * @author <a href="http://utageworks.com">kkotaro0111</a>
 * @version 1.0
 */
/**
 * @namespace Management for cell unreaded
 */
var unreadManager = {};

/**
 * 未読セルを抽出し、そのセルに対して、既読判定をする
 * @function
 */
unreadManager.unreadcheck = function() {
	var unreads = $("#lines").find(".unread");
	unreads.each(unreadManager.unread2read);
};

/**
 * 未読セルに対し、画面に表示されていたら既読処理をする
 * @function
 * @param {Number} index セルのインデックス。eachメソッドの既定引数として用意しているだけなので、使用していない
 * @param {Dom} cell_dom 1つの未読セル。このセルに対して既読処理を行う
 */
unreadManager.unread2read = function(index, cell_dom) {
	var cell = $(cell_dom);
	var bgcolor = cell.css("backgroundColor");
	var ypos = cell.offset().top + cell.height();
	if(ypos > 0 && ypos < unreadManager.lines.height()){
		cell.removeClass("unread");
		var defaultColor = cell.css("backgroundColor");
		cell.css("backgroundColor", bgcolor);
		cell.delay(1000).animate({
			backgroundColor: defaultColor
		}, 1000, function(){
			updateTitle();
		});
	}
};

/**
 * スクロール時に未読状態の判定をするメソッドを呼ぶようにする
 * @function
 */
unreadManager.init = function(){
	unreadManager.lines = $("#lines");
	unreadManager.lines.on("scroll", unreadManager.unreadcheck);
};

$(function(){
	unreadManager.init();
});
