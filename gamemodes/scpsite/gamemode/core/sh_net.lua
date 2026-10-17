--[[
	Все сетевые сообщения в одном месте.
]]

SCP.NetMessages = {
	"scp.notify", "scp.fade",
	-- меню и лобби
	"scp.menu.state", "scp.menu.solo", "scp.menu.multi", "scp.menu.back",
	"scp.lobby.sync", "scp.lobby.model", "scp.lobby.name", "scp.lobby.invite", "scp.lobby.invited",
	"scp.lobby.answer", "scp.lobby.leave", "scp.lobby.kick", "scp.lobby.start", "scp.lobby.chapter",
	-- точки
	"scp.points", "scp.edit", "scp.edit.act",
	-- сюжет
	"scp.story.state", "scp.story.say", "scp.story.end", "scp.story.fx", "scp.story.leave", "scp.dialog", "scp.cutscene", "scp.cutscene.skip", "scp.interact", "scp.interact.act", "scp.lean", "scp.shout",
	-- чат и голос
	"scp.chat.say", "scp.chat.msg", "scp.chat.typing", "scp.voice.radio",
	-- инвентарь и статистика
	"scp.inv.sync", "scp.inv.use", "scp.inv.drop", "scp.stats", "scp.stats.req",
	-- фразы
	"scp.phrase", "scp.phrase.req",
}

if SERVER then
	for _, name in ipairs(SCP.NetMessages) do
		util.AddNetworkString(name)
	end
end
