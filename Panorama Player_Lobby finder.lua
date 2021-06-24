local http = require "gamesense/http"
local base64 = require "gamesense/base64"
local ffi = require "ffi"
local bit = require "bit"

local BASE_URL = "https://sapphyr.us/looking-to-play/v4/"
local ADVERTISE_TIMEOUT = 60
local XOR_KEY = "UK6NHKqtyQHLF2TFkGwJkbHEQg3QXFS5CxDvYJSRSkVSjY6BuCTfQydnqz9fXZ2zQYP3pUPMuT8sCxzttj3QrfhjDfVFxpWtgU2SmS5DXZB8CD9thkG3fX6MGm63yWRM4QG5exuFyYFfWHW7cpuZng2cEWMhrfjX9sPPXezM4MsAAZbzXkUujGfXRzW7p2npNUCf8aUqXTnwstHZP9dxntPf2QDTVQXyQvupjgAkCEnj8PWRkJ93Dp2sSZucJ7pnWVH3ACRhBnQrb4cmNJrC8McDbTvXmtxMtkXwdbfrYyCFnn49bxBKHsjRYmFAHVhYUPcDS6WC24Z383UaDUq4Jjd8pNCYykspGzzgCcZNtH3zKcaE6ShSF5h6vdgn5mvuSJKpcAk4kZNMj38LtVYQuUR6WKymcerUsbdDFqR2GQbqTHYEg9RSkgeVTrchWBxmzu6Lc6E7hLYXNMvDsVCKpANZMj4kDxbJS6GCSHEhP3pFHGz9WszbmGUarn5zJcpy8XknQyARzRnmq9H2xP7FdKnatvx3mRAa7KX6y9YdyNxDbbSNmScR7pArMUHE2xsuwTXRDGnfqMjQ8xBbHCPBJvGH54CWu7F7MykXvKE2MxeARnyfC6vPLByn7AkgGEnrUbQF7MsTzRwZFgRMq9bA7x8KLmuCaJQx5NDxEedEjz6T75TWp7rayAMWt9PJEqnQbafpV6mPeCwuTC5kXhqxdHFu8WZguzvB4hDe6Vtpb8kuWb7vcbsvTHp8gEj7rDyUN4mwyX5djx73pqXqa9tnFVpQ5anCXyRXf7hAEhQu8UQftXhsWSGSFzGJhJ2LE8bCR4ek2KLaCH87q3LVX3BHQvBhjRhQ8gdLM4XzAcRkMWa3fQJkZ68EF4PxZxkReBccJ43ekGgJSVBxXYpVg3NjUyR9jKPjXLjGHpum2VDMBzVPwgzPnxXBEsAzB9NXYvcKnQxXrVfHkgd5vk3B3aJgkbtWZJn8T2hQv8WmDesfe5utdK2fXwtELXV7B7Svqbuz"

local next_add, next_refresh, next_herobrine_tick = 0, 0, 0
local active_category, active_category_prev
local localdata_prev
local remove_token

local bit_band, bit_rshift, bit_bxor, bit_bnot = bit.band, bit.rshift, bit.bxor, bit.bnot
local string_format, string_reverse, string_byte = string.format, string.reverse, string.byte
local ffi_copy, ffi_new, ffi_string = ffi.copy, ffi.new, ffi.string
local json_stringify, math_abs, base64_encode = json.stringify, math.abs, base64.encode

local game_js = panorama.loadstring([[
var _this = this
var toString_text = "function toString() { [native code] }"

var _GetLocalData = function() {
	var xuid = MyPersonaAPI.GetXuid()
	var members = []
	var prime = PartyListAPI.GetFriendPrimeEligible(xuid)

	var rank = FriendsListAPI.GetFriendCompetitiveRank(xuid, "competitive")
	var rank_count = 1
	var is_leader = true

	var checked = [
		// ["MyPersonaAPI", "GetXuid"],
		["LobbyAPI", "IsSessionActive"],
		["LobbyAPI", "BIsHost"],
		["PartyListAPI", "GetCount"],
		["PartyListAPI", "GetXuidByIndex"],
		["PartyListAPI", "GetFriendPrimeEligible"],
		["PartyListAPI", "GetFriendCompetitiveRank"]
	]

	try {
		for(i = 0; i < 6; i++) {
			var name = checked[i]
			var func = _this[ name[0] ][ name[1] ]
			if(func.toString() != `function ${name[1]}() { [native code] }` || func.toString.toString() != toString_text || func.toString.toString.toString() != toString_text){
				return {}
			}
		}
	} catch(e) {
		return {}
	}

	if(LobbyAPI.IsSessionActive()) {
		is_leader = LobbyAPI.BIsHost();
		for (i = 0; i < PartyListAPI.GetCount(); i++) {
			var member_xuid = PartyListAPI.GetXuidByIndex(i)
			if(member_xuid != xuid) {
				members.push(member_xuid)

				if(!PartyListAPI.GetFriendPrimeEligible(member_xuid)) {
					prime = false
				}

				var member_rank = PartyListAPI.GetFriendCompetitiveRank(member_xuid, "competitive")
				if(member_rank > 0) {
					rank += member_rank
					rank_count += 1
				}
			}
		}
	}
	return {
		steamid: xuid,
		prime: prime,
		rank: Math.floor(rank/rank_count),
		members: members.join(","),
		is_leader: is_leader
	}
}

return {
	get_local_data: _GetLocalData
}
]])()

local looking_to_play_js = panorama.loadstring([[
var panel_lobby_gamesense, panel_btn, panel_lobbies_list, panel_refresh_default, panel_refresh_gamesense
var panel_parent, panel_dz, panel_coop
var panel_advert_gs, panel_advert_btn, panel_advert_toggle, panel_advert_gs_img
var panel_herobrine, hero_rank_img, hero_chat_msg, party_member_parent

var tile_layout, chat_message_layout, advert_layout, partymember_layout, avatar_layout, herobrine_chat_message_layout

var active_category = null
var players = []
var PPList = []
var PPData = {}
var reserved
var herobrinejoined, herobrine_active

var autoJoinToggle = false

var CategoryNames = {
	legit: "Legit",
	semirage: "Semi-Rage",
	rage: "Full Rage"
}

var CheckboxImages = {
	true: "file://{images}/icons/ui/checkbox.svg",
	false: "https://i.imgur.com/DyZtfUB.png"
}

var CountryNames = {KW:"Kuwait",MA:"Morocco ",AF:"Afghanistan",AL:"Albania",DZ:"Algeria",AS:"American Samoa",AD:"Andorra",AO:"Angola",AI:"Anguilla",AQ:"Antarctica",AG:"Antigua and Barbuda",AR:"Argentina",AM:"Armenia",AW:"Aruba",AU:"Australia",AT:"Austria",AZ:"Azerbaijan",BS:"Bahamas",BH:"Bahrain",BD:"Bangladesh",BB:"Barbados",BY:"Belarus",BE:"Belgium",BZ:"Belize",BJ:"Benin",BM:"Bermuda",BT:"Bhutan",BO:"Bolivia",BA:"Bosnia and Herzegovina",BW:"Botswana",BV:"Bouvet Island",BR:"Brazil",IO:"British Indian Ocean Territory",BN:"Brunei Darussalam",BG:"Bulgaria",BF:"Burkina Faso",BI:"Burundi",KH:"Cambodia",CM:"Cameroon",CA:"Canada",CV:"Cape Verde",KY:"Cayman Islands",CF:"Central African Republic",TD:"Chad",CL:"Chile",CN:"China",CX:"Christmas Island",CC:"Cocos (Keeling) Islands",CO:"Colombia",KM:"Comoros",CG:"Congo",CD:"Congo, the Democratic Republic of the",CK:"Cook Islands",CR:"Costa Rica",CI:"Cote D'Ivoire",HR:"Croatia",CU:"Cuba",CY:"Cyprus",CZ:"Czech Republic",DK:"Denmark",DJ:"Djibouti",DM:"Dominica",DO:"Dominican Republic",EC:"Ecuador",EG:"Egypt",SV:"El Salvador",GQ:"Equatorial Guinea",ER:"Eritrea",EE:"Estonia",ET:"Ethiopia",FK:"Falkland Islands (Malvinas)",FO:"Faroe Islands",FJ:"Fiji",FI:"Finland",FR:"France",GF:"French Guiana",PF:"French Polynesia",TF:"French Southern Territories",GA:"Gabon",GM:"Gambia",GE:"Georgia",DE:"Germany",GH:"Ghana",GI:"Gibraltar",GR:"Greece",GL:"Greenland",GD:"Grenada",GP:"Guadeloupe",GU:"Guam",GT:"Guatemala",GN:"Guinea",GW:"Guinea-Bissau",GY:"Guyana",HT:"Haiti",HM:"Heard Island and Mcdonald Islands",VA:"Holy See (Vatican City State)",HN:"Honduras",HK:"Hong Kong",HU:"Hungary",IS:"Iceland",IN:"India",ID:"Indonesia",IR:"Iran, Islamic Republic of",IQ:"Iraq",IE:"Ireland",IL:"Israel",IT:"Italy",JM:"Jamaica",JP:"Japan",JO:"Jordan",KZ:"Kazakhstan",KE:"Kenya",KI:"Kiribati",KP:"North Korea",KR:"South Korea",KW:"Kuwait",KG:"Kyrgyzstan",LA:"Lao People's Democratic Republic",LV:"Latvia",LB:"Lebanon",LS:"Lesotho",LR:"Liberia",LY:"Libya",LI:"Liechtenstein",LT:"Lithuania",LU:"Luxembourg",MO:"Macao",MG:"Madagascar",MW:"Malawi",MY:"Malaysia",MV:"Maldives",ML:"Mali",MT:"Malta",MH:"Marshall Islands",MQ:"Martinique",MR:"Mauritania",MU:"Mauritius",YT:"Mayotte",MX:"Mexico",FM:"Micronesia, Federated States of",MD:"Moldova, Republic of",MC:"Monaco",MN:"Mongolia",MS:"Montserrat",MA:"Morocco",MZ:"Mozambique",MM:"Myanmar",NA:"Namibia",NR:"Nauru",NP:"Nepal",NL:"Netherlands",NC:"New Caledonia",NZ:"New Zealand",NI:"Nicaragua",NE:"Niger",NG:"Nigeria",NU:"Niue",NF:"Norfolk Island",MK:"North Macedonia, Republic of",MP:"Northern Mariana Islands",NO:"Norway",OM:"Oman",PK:"Pakistan",PW:"Palau",PS:"Palestinian Territory, Occupied",PA:"Panama",PG:"Papua New Guinea",PY:"Paraguay",PE:"Peru",PH:"Philippines",PN:"Pitcairn",PL:"Poland",PT:"Portugal",PR:"Puerto Rico",QA:"Qatar",RE:"Reunion",RO:"Romania",RU:"Russia",RW:"Rwanda",SH:"Saint Helena",KN:"Saint Kitts and Nevis",LC:"Saint Lucia",PM:"Saint Pierre and Miquelon",VC:"Saint Vincent and the Grenadines",WS:"Samoa",SM:"San Marino",ST:"Sao Tome and Principe",SA:"Saudi Arabia",SN:"Senegal",SC:"Seychelles",SL:"Sierra Leone",SG:"Singapore",SK:"Slovakia",SI:"Slovenia",SB:"Solomon Islands",SO:"Somalia",ZA:"South Africa",GS:"South Georgia and the South Sandwich Islands",ES:"Spain",LK:"Sri Lanka",SD:"Sudan",SR:"Suriname",SJ:"Svalbard and Jan Mayen",SZ:"Eswatini",SE:"Sweden",CH:"Switzerland",SY:"Syrian Arab Republic",TW:"Taiwan",TJ:"Tajikistan",TZ:"Tanzania, United Republic of",TH:"Thailand",TL:"Timor-Leste",TG:"Togo",TK:"Tokelau",TO:"Tonga",TT:"Trinidad and Tobago",TN:"Tunisia",TR:"Turkey",TM:"Turkmenistan",TC:"Turks and Caicos Islands",TV:"Tuvalu",UG:"Uganda",UA:"Ukraine",AE:"United Arab Emirates",GB:"United Kingdom",US:"USA",UM:"United States Minor Outlying Islands",UY:"Uruguay",UZ:"Uzbekistan",VU:"Vanuatu",VE:"Venezuela",VN:"Vietnam",VG:"Virgin Islands, British",VI:"Virgin Islands, U.S.",WF:"Wallis and Futuna",EH:"Western Sahara",YE:"Yemen",ZM:"Zambia",ZW:"Zimbabwe",AX:"Åland Islands",BQ:"Bonaire, Sint Eustatius and Saba",CW:"Curaçao",GG:"Guernsey",IM:"Isle of Man",JE:"Jersey",ME:"Montenegro",BL:"Saint Barthélemy",MF:"Saint Martin (French part)",RS:"Serbia",SX:"Sint Maarten (Dutch part)",SS:"South Sudan",XK:"Kosovo"}

var gameModes = [
	{
		category: "legit",
		name: "Legit Cheating",
		img: "<img src='https://raw.githubusercontent.com/Karechta/looking_for_gs/master/legit.png' style='min-height: 200px !important; height: 200px !important;' class='' />"
	},
	{
		category: "semirage",
		name: "Semi-Raging",
		img: "<img src='file://{images}/icons/ui/quest.svg' />"
	},
	{
		category: "rage",
		name: "Full Raging",
		img: "<img src='https://raw.githubusercontent.com/Karechta/looking_for_gs/master/rage.png' />"
	}
]

var needsRefresh = 0
var gamesenseTabActive = false
var loadProgress = 100
var joinXuid = null
var inviteXuids = {}
var invitedByXuids = {}
var in_lobby_prev = null
var active_friendlobby_tooltip = null
var active_hire_toggle_context_menu = null

var PartyBrowserAPI_prev = {
	GetResultsCount: PartyBrowserAPI.GetResultsCount,
	GetXuidByIndex: PartyBrowserAPI.GetXuidByIndex,
	GetPartyMembersCount: PartyBrowserAPI.GetPartyMembersCount,
	GetPartyMemberXuid: PartyBrowserAPI.GetPartyMemberXuid,
	GetPartySessionSetting: PartyBrowserAPI.GetPartySessionSetting,
	SetSearchFilter: PartyBrowserAPI.SetSearchFilter,
	Refresh: PartyBrowserAPI.Refresh,
	GetProgress: PartyBrowserAPI.GetProgress,
	GetPartyType: PartyBrowserAPI.GetPartyType
}

var GameInterfaceAPI_prev = {
	SetSettingString: GameInterfaceAPI.SetSettingString
}

PartyBrowserAPI.SetSearchFilter = function(filter) {
	if (gamesenseTabActive) {
		needsRefresh = 1
		_SetLoadProgress(20)
	}

	return PartyBrowserAPI_prev.SetSearchFilter.call(PartyBrowserAPI, filter)
}

var _UpdateNoDataText = function(){
	var panel_list = $.GetContextPanel().FindChildTraverse("JsFriendsList-lobbies").FindChild("JsFriendsList-List")
	if(panel_list) {
		var panel_nodata = panel_list.FindChildTraverse('JsFriendListNoData')
		if(panel_nodata) {
			var panel_nodatadesc = panel_nodata.FindChildTraverse("JsFriendsNoDataDesc")
			if(panel_nodatadesc) {
				panel_nodatadesc.text = gamesenseTabActive ? "Couldn't find any gamesense users looking to play at this time." : $.Localize("#FriendsList_nodata_advertising")
			}
		}
	}
}

var _SetFlagImageFallback = function(info){
	if(info.handler && info.country && info.element) {
		$.UnregisterEventHandler("ImageFailedLoad", info.element, info.handler)
		info.handler = null

		info.element.SetImage(`https://raw.githubusercontent.com/hjnilsson/country-flags/master/png100px/${info.country.toLowerCase()}.png`)
	}
}

PartyBrowserAPI.GetResultsCount = function() {
	_UpdateNoDataText()
	if (gamesenseTabActive) {
		return PPList.length
	} else {
		return PartyBrowserAPI_prev.GetResultsCount.call(PartyBrowserAPI)
	}
}

PartyBrowserAPI.GetProgress = function() {
	_UpdateNoDataText()
	if (gamesenseTabActive) {
		return loadProgress
	} else {
		return PartyBrowserAPI_prev.GetProgress.call(PartyBrowserAPI)
	}
}

PartyBrowserAPI.GetXuidByIndex = function(i) {
	if (gamesenseTabActive) {
		return PPList[i]
	} else {
		return PartyBrowserAPI_prev.GetXuidByIndex.call(PartyBrowserAPI, i)
	}
}

PartyBrowserAPI.GetPartyMembersCount = function(xuid) {
	if (gamesenseTabActive && PPData[xuid]) {
		return PPData[xuid].members ? PPData[xuid].members.length+1 : 1
	} else {
		return PartyBrowserAPI_prev.GetPartyMembersCount.call(PartyBrowserAPI, xuid, i)
	}
}

PartyBrowserAPI.GetPartyType = function(xuid) {
	if (gamesenseTabActive && PPData[xuid]) {
		return null
	} else {
		return PartyBrowserAPI_prev.GetPartyType.call(PartyBrowserAPI, xuid)
	}
}

PartyBrowserAPI.GetPartyMemberXuid = function(xuid, i) {
	if (gamesenseTabActive && PPData[xuid]) {
		return i == 0 ? xuid : (PPData[xuid].members ? PPData[xuid].members[i-1] : null)
	} else {
		return PartyBrowserAPI_prev.GetPartyMemberXuid.call(PartyBrowserAPI, xuid, i)
	}
}

PartyBrowserAPI.GetPartySessionSetting = function(xuid, setting) {
	if (gamesenseTabActive && PPData[xuid]) {
		if (setting == "game/loc") {
			var panel_list = $.GetContextPanel().FindChildTraverse("JsFriendsList-lobbies").FindChild("JsFriendsList-List")
			var tile = panel_list.FindChild(xuid)

			if (tile) {
				if(PPData[xuid].members) {
					elFriendLobby = tile.FindChildTraverse("JsFriendAdvertiseGSLobby")
					var isFirst = false
					if(elFriendLobby == null) {
						tile.style.height = "100px"
						tile.Children().forEach(function(el){
							el.visible = false
						})

						elFriendLobby = $.CreatePanel("Panel", tile, "JsFriendAdvertiseGSLobby")
						elFriendLobby.SetAttributeString('xuid', xuid)
						elFriendLobby.BLoadLayout('file://{resources}/layout/friendlobby.xml', false, false)
						isFirst = true
					}
					if(elFriendLobby != null) {
						FriendLobby_Init(elFriendLobby, xuid, isFirst)
					}
				}

				var country = PPData[xuid].country
				if(country) {
					var elFlagImgId = `JsFriendLobbyFlagCustom-${xuid}`
					var elFlagImg = tile.FindChildTraverse(elFlagImgId)
					if(elFlagImg == null) {
						var parent
						if(PPData[xuid].members) {
							parent = tile.FindChildTraverse("JsFriendLobbyFlag").GetParent()
						} else {
							parent = tile.FindChildTraverse("JsFriendAdvertiseFlag").GetParent()
						}

						elFlagImg = $.CreatePanel("Image", parent, elFlagImgId, {
							//texturewidth: 38,
							textureheight: 20,
							class: "friendlobby__row__icon-flag"
						})
						elFlagImg.style.height = "20px"
						//elFlagImg.style.width = "38px"

						if(PPData[xuid].members) {
							parent.MoveChildAfter(elFlagImg, tile.FindChildTraverse('JsFriendLobbySkillGroup'))
						} else {
							parent.MoveChildAfter(elFlagImg, tile.FindChildTraverse("JsFriendAdvertiseFlag"))
						}

						elFlagImg.SetPanelEvent("onmouseout", _CountryMouseout)

						var info = {
							element: elFlagImg,
							country: country
						}
						info.handler = $.RegisterEventHandler("ImageFailedLoad", elFlagImg, _SetFlagImageFallback.bind(undefined, info))

						elFlagImg.SetImage(`file://{images}/flags/${country}.png`)
						elFlagImg.SetPanelEvent("onmouseover", _CountryMouseover.bind(undefined, elFlagImgId, country))
						elFlagImg.RemoveClass('hidden')
						elFlagImg.style.tooltipPosition = "bottom"
						
					}
				}

				var elCategory = tile.FindChildTraverse("JsFriendAdvertiseGSCategory")
				if (elCategory == null) {
					var parent
					if(PPData[xuid].members) {
						parent = tile.FindChildTraverse("JsFriendLobbySkillGroup").GetParent()
					} else {
						parent = tile.FindChildTraverse("JsFriendAdvertiseFlag").GetParent()
					}
					elCategory = $.CreatePanel("Panel", parent, "JsFriendAdvertiseGSCategory")

					if(PPData[xuid].members) {
						parent.MoveChildAfter(elCategory, parent.GetChild(parent.GetChildCount()-3))
						elCategory.style.paddingRight = "4px;"
					}

					if (elCategory != null) {
						elCategory.BLoadLayoutFromString(tile_layout, false, false)
					}
				}

				if (elCategory != null && elCategory.FindChildTraverse("CategoryText")) {
					var cat = PPData[xuid].category
					elCategory.FindChildTraverse("CategoryText").text = CategoryNames[cat] || cat
				}
			}
		}

		switch (setting) {
			case "game/apr":
				return PPData[xuid].prime == 1
			case "game/mode":
				return "competitive"
			case "game/ark":
				return PPData[xuid].rank * 10
			case "game/mapgroupname":
				return "workshop"
			case "game/clanid":
			case "game/clantag":
				return "gamesense"
			default:
				 //$.Msg(setting)
		}
	} else {
		return PartyBrowserAPI_prev.GetPartySessionSetting.call(PartyBrowserAPI, xuid, setting)
	}
}

PartyBrowserAPI.Refresh = function() {
	_UpdateNoDataText()
	if (!gamesenseTabActive) {
		return PartyBrowserAPI_prev.Refresh.call(PartyBrowserAPI)
	}
}


GameInterfaceAPI.SetSettingString = function( filter, value ){
	if (gamesenseTabActive && filter == 'ui_nearbylobbies_filter') {
		panel_refresh_default.visible = true
		panel_refresh_gamesense.visible = false
		gamesenseTabActive = false
		var panel_list = $.GetContextPanel().FindChildTraverse("JsFriendsList-lobbies").FindChild("JsFriendsList-List")

		panel_list.Children().forEach(function(el){
			try{
				var elFlagImgId = `JsFriendLobbyFlagCustom-${el.id}`
				el.FindChildTraverse(elFlagImgId).DeleteAsync(0.0)
				el.FindChildTraverse("JsFriendAdvertiseGSCategory").DeleteAsync(0.0)
			}
			catch(e){

			}
		})
	}


	return GameInterfaceAPI_prev.SetSettingString.call(GameInterfaceAPI, filter, value)
}


//Lobby listing Below


var FriendLobby_OpenContextMenu = function(xuid) {
	$.DispatchEvent('SidebarContextMenuActive', true)

	var contextMenuPanel = UiToolkitAPI.ShowCustomLayoutContextMenuParametersDismissEvent(
		'',
		'',
		'file://{resources}/layout/context_menus/context_menu_playercard.xml',
		'xuid='+xuid,
		function () {
			$.DispatchEvent('SidebarContextMenuActive', false )
		}
	);
	contextMenuPanel.AddClass( "ContextMenu_NoArrow" );
}

var FriendLobby_Join = function(xuid) {
	//Check if already in Lobby
	if(LobbyAPI.IsSessionActive()) {
		for (i = 0; i < PartyListAPI.GetCount(); i++) {
			var member_xuid = PartyListAPI.GetXuidByIndex(i)

			if(member_xuid == xuid) {
				return
			}
		}
	}
	//Set JoinXuid to be called by NeedsUpdate
	$.DispatchEvent('PlaySoundEffect', 'PanoramaUI.Lobby.Joined', 'MOUSE')
	joinXuid = xuid
}

var FriendLobby_SlotMouseover = function(id){
	active_friendlobby_tooltip = id
	UiToolkitAPI.ShowTextTooltip(id, "Join game<font color='#95b806'>sense</font> lobby")
}

var FriendLobby_SlotMouseout = function(id){
	active_friendlobby_tooltip = null
	UiToolkitAPI.HideTextTooltip()
}

var _CountryMouseover = function(id, country){
	UiToolkitAPI.ShowTextTooltip(id, `${CountryNames[country] || country}`)
}

var _CountryMouseout = function(id, country){
	UiToolkitAPI.HideTextTooltip()
}

var FriendLobby_Init = function(elFriendLobby, xuid, isFirst) {
	elFriendLobby.style.borderBottom = "1px solid rgba(255, 255, 255, 0) !important;"

	// La Familia de El
	var elPrime = elFriendLobby.FindChildTraverse('JsFriendLobbyPrime')
	var elSkillGroupImg = elFriendLobby.FindChildTraverse('JsFriendLobbySkillGroup')
	var elSettingsLabel = elFriendLobby.FindChildTraverse('JsFriendLobbySettings')
	var elGroupLBtn = elFriendLobby.FindChildTraverse('JsFriendLobbyGroupBtn')
	var elGroupLabel = elFriendLobby.FindChildTraverse('JsFriendLobbyGroupTxt')
	var elAvatarRow = elFriendLobby.FindChildTraverse('JsFriendLobbyAvatars')

	if(isFirst) {
		elFriendLobby.visible = true
		elFriendLobby.RemoveClass('hidden')

		var parent = elSkillGroupImg.GetParent()
		elPrime.SetParent(parent)
		parent.MoveChildBefore(elPrime, elSkillGroupImg)

		elFriendLobby.FindChildTraverse('JsFriendLobbyLeaderAvatar').steamid = xuid
		elFriendLobby.FindChildTraverse('JsFriendLobbyLeaderBtn').SetPanelEvent('onactivate', FriendLobby_OpenContextMenu.bind(undefined, xuid))
	}
	elFriendLobby.SetDialogVariable('friendname', FriendsListAPI.GetFriendName(xuid))
	elFriendLobby.FindChildTraverse('JsFriendLobbyLeaderName').text = "#tooltip_lobby_leader_name"
	elFriendLobby.FindChildTraverse('JsFriendLobbyLeaderName').style.fontWeight = "bold"

	elSkillGroupImg.RemoveClass('hidden')
	elSkillGroupImg.SetImage(`file://{images}/icons/skillgroups/skillgroup${PPData[xuid].rank}.svg`)

	elSettingsLabel.text = CategoryNames[PPData[xuid].category]
	elSettingsLabel.visible = false

	elGroupLBtn.visible = false
	elGroupLabel.visible = false

	elPrime.visible = PPData[xuid].prime;

	var inLobby = false
	for(var i=0; i < PartyBrowserAPI.GetPartyMembersCount(xuid); i++) {
		if(PartyBrowserAPI.GetPartyMemberXuid(xuid, i) == MyPersonaAPI.GetXuid()) {
			inLobby = true
			break
		}
	}

	elFriendLobby.FindChildTraverse('JsFriendLobbyLeaderAvatar').style.margin = "0px 7px;"
	for (var i = 1; i <= 4; i++) {
		var _xuid = PartyBrowserAPI.GetPartyMemberXuid(xuid, i)
		var slotId = xuid + ':' + i
		var playerSlot = elAvatarRow.FindChild(slotId)

		if (!playerSlot) {
			playerSlot = $.CreatePanel('Panel', elAvatarRow, slotId);
			playerSlot.BLoadLayoutSnippet('FriendLobbyAvatarSlot');
		}

		playerSlot.style.margin = "0px 12px;"

		if (i === 1)
			playerSlot.AddClass('friendlobby__slot--first');

		var elAvatar = playerSlot.FindChildTraverse('JsFriendAvatar'),
			elJoinBtn = playerSlot.FindChildTraverse('JsFriendAvatarJoin');

		if (!_xuid) {
			if(inLobby) {
				elJoinBtn.enabled = false;
				elJoinBtn.visible = false;
				elAvatar.visible = false;
			} else {
				elJoinBtn.enabled = true;
				elJoinBtn.visible = true;
				elAvatar.visible = false;

				elJoinBtn.SetPanelEvent('onactivate', FriendLobby_Join.bind(undefined, xuid))
				elJoinBtn.SetPanelEvent('onmouseover', FriendLobby_SlotMouseover.bind(undefined, slotId))
				elJoinBtn.SetPanelEvent('onmouseout', FriendLobby_SlotMouseout.bind(undefined, slotId))
			}
		} else {
			elJoinBtn.visible = false;
			elAvatar.visible = true;
			elAvatar.steamid = _xuid;

			playerSlot.FindChild('JsFriendAvatarBtn').SetPanelEvent('onactivate', FriendLobby_OpenContextMenu.bind(undefined, _xuid));
		}
	}
}

// used to Change the active Category and update the Buttons Visuals
var _SetActiveCategory = function(_active_category) {
	active_category = _active_category

	if (active_category != null) {
		panel_advert_gs_img.style.washColor = "#95b806;"
		panel_advert_gs_img.style.backgroundColor = "rgba(0, 0, 0, 0.4);"
		panel_advert_gs_img.style.boxShadow = "0px 0px 6px 5.0 rgba(0, 0, 0, 0.753);"
		panel_advert_gs_img.style.imgShadow = "0px 0px 1px 1.0 white;"

		$.DispatchEventAsync(0.0, "PlaySoundEffect", "UIPanorama.mainmenu_press_quit", "MOUSE")
	} else {
		panel_advert_gs_img.style.washColor = "white;"
		panel_advert_gs_img.style.backgroundColor = "rgba(0, 0, 0, 0);"
		panel_advert_gs_img.style.boxShadow = "0px 0px 0px 0 rgba(0, 0, 0, 0);"
		panel_advert_gs_img.style.imgShadow = "0px 0px 0px 0.0 white;"
	}
}

var _OnActiveHireToggleContextMenuDismissed = function(){
	active_hire_toggle_context_menu = null
}

// Create Advert Button
var _Create_Advert = function() {
	panel_advert_toggle = $.GetContextPanel().FindChildTraverse("HireAdvertisingToggleContainer")
	var advert_toggle_parent = panel_advert_toggle.GetParent()
	var advert_toggle_parent_parent = advert_toggle_parent.GetParent()

	panel_advert_toggle.GetParent().style.borderBottom = "1px solid rgba(255, 255, 255, 0) !important;"

	panel_advert_gs = $.CreatePanel("Panel", advert_toggle_parent_parent, "AdvertGS")
	if (panel_advert_gs.BLoadLayoutFromString(advert_layout, false, false)) {
		panel_advert_gs.SetParent(advert_toggle_parent_parent)
		advert_toggle_parent_parent.MoveChildAfter(panel_advert_gs, advert_toggle_parent)

		panel_advert_btn = panel_advert_gs.FindChildTraverse("HireAdvertisingToggleGS")
		if (panel_advert_btn != null) {
			panel_advert_btn.SetPanelEvent("onactivate", _OnActivateToggle)
			panel_advert_btn.SetPanelEvent("oncontextmenu", _OnActivateToggle)
			panel_advert_btn.SetPanelEvent("onmouseover", _OnHover_toggle)
			panel_advert_btn.SetPanelEvent("onmouseout", function() {
				UiToolkitAPI.HideTitleTextTooltip()
			})
		}
	}
	panel_advert_gs_img = panel_advert_gs.FindChildTraverse("HireAdvertisingToggleGSImage")

}

// Function to check if Player is able to Advertise
var _CanAdvertise = function() {
	return !(PartyListAPI.GetCount() > 4 || FriendsListAPI.IsLocalPlayerPlayingMatch() || MyPersonaAPI.IsVacBanned() || CompetitiveMatchAPI.GetCooldownSecondsRemaining() > 0)
}

// returns active category and resets if above function returns false
var _GetActiveCategory = function() {
	if (active_category && !_CanAdvertise()) {
		_SetActiveCategory(null)
	}

	return active_category
}

// Called by clicking on the Advertise Button, lists the modes to look for
var _OnActivateToggle = function() {
	if (!_CanAdvertise()) {
		return
	}

	var items = []

	gameModes.forEach(entry => {
		var labelLoc
		if (entry.category === active_category) {
			labelLoc = `${entry.img} <b><font color='#95b806'>Looking for ${entry.name}</font></b>`
		} else {
			labelLoc = `${entry.img} Looking for ${entry.name}`
		}

		items.push({
			label: labelLoc,
			style: "Icon",
			jsCallback: _SetActiveCategory.bind(undefined, entry.category)
		})
	})

	if (!(PartyListAPI.GetCount() > 1)){
		var checkLabel = `<img src="${CheckboxImages[autoJoinToggle]}" /> Auto-join`
		items.push({
			label: checkLabel,
			style: "Icon",
			jsCallback: function(){
				autoJoinToggle = !autoJoinToggle
				_OnActivateToggle()
			}
		})
	}


	if(active_category != null) {
		items.push({
			label: "Stop Looking",
			style: "TopSeparator",
			jsCallback: function(){
				_SetActiveCategory(null)

				$.DispatchEventAsync(0.0, "PlaySoundEffect", "UIPanorama.generic_button_press", "MOUSE")
			}
		})
	}

	// create new popup
	//active_hire_toggle_context_menu = UiToolkitAPI.ShowSimpleContextMenuWithDismissEvent('HireAdvertisingToggleGS', 'ControlLibSimpleContextMenu', items, _OnActiveHireToggleContextMenuDismissed)
	active_hire_toggle_context_menu = UiToolkitAPI.ShowSimpleContextMenuWithDismissEvent('', 'ControlLibSimpleContextMenu', items, _OnActiveHireToggleContextMenuDismissed)

	// try and find auto-join button
	var auto_join_toggle_btn
	active_hire_toggle_context_menu.FindChildTraverse("ContextMenuBody").Children().forEach(function(el){
		if(el.GetChild(0) && el.GetChild(0).text && el.GetChild(0).text.includes("Auto-join")){
			auto_join_toggle_btn = el
		}
	})

	// add our custom hover handlers
	if(auto_join_toggle_btn) {
		// $.Msg(auto_join_toggle_btn)
		// $.Msg(auto_join_toggle_btn.Children())
		// $.Msg(auto_join_toggle_btn.Children()[0].Children())

		auto_join_toggle_btn.SetPanelEvent("onactivate", function(){
			$.DispatchEvent('PlaySoundEffect', 'UIPanorama.generic_button_press', 'MOUSE')
			autoJoinToggle = !autoJoinToggle
			// $.Msg(autoJoinToggle)

			// update image
			if(auto_join_toggle_btn && auto_join_toggle_btn.GetChild(0) && auto_join_toggle_btn.GetChild(0).GetChild(0)){
				auto_join_toggle_btn.GetChild(0).GetChild(0).SetImage(CheckboxImages[autoJoinToggle])
			}
		})
	}
}

// Tooltip on Hover
var _OnHover_toggle = function() {
	UiToolkitAPI.ShowTitleTextTooltip("AdvertGS", "Looking for game<font color='#95b806'>sense</font> users", "Enables other users to find you and invite you to a lobby")
}


//EasterEgg for the Scares
var joinHerobrine = function(){
	if (!herobrinejoined == true && PartyListAPI.IsPartySessionActive() && PartyListAPI.GetCount() > 1){
		party_member_parent = $.GetContextPanel().FindChildTraverse( 'PartyMembers' )
		panel_herobrine = $.CreatePanel( "Panel", party_member_parent,  'Herobrine' )
		herobrinejoined = true
		if (panel_herobrine.BLoadLayoutFromString(partymember_layout, false, false)) {
	
			panel_herobrine.visible = true
			herobrine_active = true

			var hero_btn = panel_herobrine.FindChildTraverse("HerobrineBtn")
			
			if (hero_btn != null){
				hero_btn.SetPanelEvent("onactivate",_RemoveHerobrine)
				hero_btn.SetPanelEvent("onmouseover",function() {
					$.Schedule(0.1,_RemoveHerobrine)
				})
			}

			var hero_avatar = $.CreatePanel( "Panel", hero_btn, "HerobrineAvatarPanel" )
			if (hero_avatar.BLoadLayoutFromString(avatar_layout, false, false)) {
				hero_btn.MoveChildBefore(hero_avatar,hero_btn.GetChild(0))
			}

			var hero_name = panel_herobrine.FindChildTraverse("JsFriendName")
			if (hero_name != null){
				hero_name.style.washColor = "#FF1C1C;"
				hero_name.style.backgroundColor = "rgba(255, 28, 28, 0);"
				hero_name.style.boxShadow = "0px 0px 0px 0 rgba(255, 28, 28, 0);"
				hero_name.style.imgShadow = "0px 0px 0px 0.0 #FF1C1C;"
			}

			hero_rank_img = panel_herobrine.FindChildTraverse("HerobrineRank")
		}

		var lines = $.GetContextPanel().FindChildTraverse("ChatLinesContainer")
		hero_chat_msg = $.CreatePanel("Panel", lines, "")
		if(hero_chat_msg != null) {
			if(hero_chat_msg.BLoadLayoutFromString(herobrine_chat_message_layout, false, false)) {
				hero_chat_msg.SetParent(lines)
				lines.MoveChildBefore(hero_chat_msg, lines.GetChild(0))
				hero_chat_msg.FindChildTraverse("parent").style.backgroundColor = "gradient( linear, 0% 0%, 100% 0%, from(#2E2E2D), to( rgba(0, 0, 0, 0.0)) );"
			}
			$.Schedule(0.1,function() {
				lines.ScrollToBottom()
			})
		}
		$.DispatchEvent('PlaySoundEffect', 'PanoramaUI.Lobby.Joined', 'MOUSE')
	}
}

var _HerobrineRankCall = function(){

	if (herobrine_active == true){
		try{
			var s = Math.floor(Math.random() * 18)+1
			hero_rank_img.SetImage( 'file://{images}/icons/skillgroups/skillgroup' + s + '.svg' )
		}
		catch (e) {
			herobrine_active = false
			_RemoveHerobrine
			//$.Msg(e)
		}
	}
}

var _HerobrineSummonTry = function(){
	if (PartyListAPI.IsPartySessionActive() && PartyListAPI.GetCount() > 1 && !FriendsListAPI.IsLocalPlayerPlayingMatch()){
		var x = Math.random()
		if(x <= 0.000003){
			var y = Math.floor(Math.random() *30)
			$.Schedule(y, joinHerobrine)
		}
	}
}

//Make People sad
var _RemoveHerobrine = function(){
	try{
		if (hero_chat_msg != null) {
			hero_chat_msg.visible = false
			hero_chat_msg.RemoveAndDeleteChildren()
			hero_chat_msg.DeleteAsync(0.0)
			hero_chat_msg = null
		} 
	}
	catch(e){

	}
	try{
		if (panel_herobrine != null) {
			panel_herobrine.visible = false
			panel_herobrine.RemoveAndDeleteChildren()
			panel_herobrine.DeleteAsync(0.0)
			panel_herobrine = null
		} 
	}
	catch(e){
		//$.Msg(e)
	}

	herobrine_active = false
}

// Create LTP Tab, to show GS users

var _Create_LTP_Tab = function(layout) {
	panel_coop = $.GetContextPanel().FindChildTraverse("JsFriendsList-lobbies-toolbar-button-cooperative")
	panel_dz = $.GetContextPanel().FindChildTraverse("JsFriendsList-lobbies-toolbar-button-survival")
	panel_parent = panel_dz.GetParent()

	panel_lobby_gamesense = $.CreatePanel('Button', panel_parent, 'Gamesense_Lobbies')
	if (panel_lobby_gamesense.BLoadLayoutFromString(layout, false, false)) {
		panel_lobby_gamesense.visible = true
		panel_parent.MoveChildAfter(panel_lobby_gamesense, panel_coop ? panel_coop : panel_dz)

		panel_btn = panel_lobby_gamesense.FindChildTraverse("JsFriendsList-lobbies-toolbar-button-gamesense")
		if (panel_btn != null) {
			panel_btn.SetPanelEvent("onactivate", _OnActivate)
			panel_btn.SetPanelEvent("onmouseover", OnMouseOver)
			panel_btn.SetPanelEvent("onmouseout", OnMouseOut)
		}

		panel_refresh_default = panel_parent.FindChildTraverse("JsFriendsList-lobbies-toolbar-button-refresh")
		panel_refresh_gamesense = panel_lobby_gamesense.FindChildTraverse("JsFriendsList-lobbies-toolbar-button-gamesense-refresh")
		panel_refresh_gamesense.SetParent(panel_refresh_default.GetParent())
		if (panel_refresh_gamesense != null) {
			panel_refresh_gamesense.GetParent().MoveChildBefore(panel_refresh_gamesense, panel_refresh_default)
			panel_refresh_gamesense.visible = false

			panel_refresh_gamesense.SetPanelEvent("onactivate", function() {
				_SetLoadProgress(20)
				needsRefresh = 1

				if (PartyListAPI.IsPartySessionActive() && PartyListAPI.GetCount() > 1){
					var x = Math.random()
					if(x <= 0.000003){
						var y = Math.floor(Math.random() *30)
						$.Schedule(y, joinHerobrine)
					}
				}
			})
		}
	}

}

// Disable default refresh / player buttons, and request a Playerlist refresh
var _OnActivate = function() {
	gamesenseTabActive = true
	_SetLoadProgress(10)
	needsRefresh = 1

	panel_refresh_default.visible = false
	panel_refresh_gamesense.visible = true
	$.DispatchEventAsync(0.0, "PanoramaComponent_PartyBrowser_Refresh")
}

//Tooltip On
var OnMouseOver = function() {
	UiToolkitAPI.ShowTextTooltip("JsFriendsList-lobbies-toolbar-button-gamesense", "game<font color='#95b806'>sense</font>")
}

//Tooltip Off
var OnMouseOut = function() {
	UiToolkitAPI.HideTextTooltip()
}

// i dont need to comment this
var _SetLoadProgress = function(progress) {
	loadProgress = progress
	$.DispatchEventAsync(0.0, "PanoramaComponent_PartyBrowser_Refresh")
}

// Uses data from the Server to convert it into a Playerlist useable in js
var _SetPP = function(data) {
	var panel_list = $.GetContextPanel().FindChildTraverse("JsFriendsList-lobbies").FindChild("JsFriendsList-List")
	if(panel_list) {
		panel_list.Children().forEach(function(tile){
			try { 
				if(!data[tile.id] || (!!PPData[tile.id].members != !!data[tile.id].members)){
					tile.RemoveAndDeleteChildren()
					tile.DeleteAsync(0.0)
				}
			} catch(e) {
				$.Schedule(0.1,PartyBrowserAPI.Refresh)
				
			}

		})
	}

	PPList = []
	PPData = {}

	if(loadProgress < 100) {
		_SetLoadProgress(80)

		var first = 0.1 + Math.random() * 0.2
		$.Schedule(first, function() {
			_SetLoadProgress(90)
		})

		$.Schedule(first + 0.1 + Math.random() * 0.2, function() {
			_SetLoadProgress(100)
		})
	}
	for (var xuid in data) {
		if(data[xuid].members) {
			PPList.unshift(xuid)
		} else {
			PPList.push(xuid)
		}
		PPData[xuid] = data[xuid]
	}
	if (gamesenseTabActive) {
		$.DispatchEventAsync(0.0, "PanoramaComponent_PartyBrowser_Refresh")
	}
}

// Invites the Player, removes his Invite, and shows a cool message in chat
var _Invite = function(xuid, isReinvite, country) {
	if(isReinvite && invitedByXuids[xuid] != true){
		return false
	}

	var delay = 0

	if( isReinvite && PartyListAPI.GetPartySessionSetting("game/mmqueue") == "searching") {
		LobbyAPI.StopMatchmaking()
		if (!LobbyAPI.BIsHost()){
			delay = 1
		}
	}

	$.Schedule(delay, function() {
		FriendsListAPI.ActionInviteFriend(xuid, '')
	})
	
	if(isReinvite) {
		var numInvites = PartyBrowserAPI.GetInvitesCount()
		for (i = 0; i < numInvites; i++) {
			var lobby_xuid = PartyBrowserAPI.GetInviteXuidByIndex(i)
			var _xuid = PartyBrowserAPI.GetPartyMemberXuid(lobby_xuid, 0)

			if(_xuid == xuid) {
				PartyBrowserAPI.ClearInvite(lobby_xuid)
				$.Schedule(0.5, function(){
					PartyBrowserAPI.ClearInvite(lobby_xuid)
				})
			}
		}

		var lines = $.GetContextPanel().FindChildTraverse("ChatLinesContainer")
		var message = $.CreatePanel("Panel", lines, "")
		if(message != null) {
			if(message.BLoadLayoutFromString(chat_message_layout, false, false)) {
				message.SetParent(lines)
				lines.MoveChildBefore(message, lines.GetChild(0))

				var elName = message.FindChildTraverse("name")
				elName.text = FriendsListAPI.GetFriendName(xuid)

				// <Image id="flag" textureheight="12" texturewidth="-1" style="padding: 3px 5px; padding-left: 2px; height: 19px; width: 29px;" />
				if(country) {
					var id = `flag-${lines.GetChildCount()}`
					var elFlag = $.CreatePanel("Image", elName.GetParent(), id)
					elName.GetParent().MoveChildAfter(elFlag, elName)

					var info = {
						element: elFlag,
						country: country
					}
					info.handler = $.RegisterEventHandler("ImageFailedLoad", elFlag, _SetFlagImageFallback.bind(undefined, info))

					elFlag.SetImage(`file://{images}/flags/${country}.png`)
					elFlag.style.padding = "3px 5px"
					elFlag.style.paddingLeft = "2px"
					elFlag.style.height = "20px"
					elFlag.style.width = "29px"

					elFlag.SetPanelEvent("onmouseover", _CountryMouseover.bind(undefined, id, country))
					elFlag.SetPanelEvent("onmouseout", _CountryMouseout)
				}
				message.FindChildTraverse("parent").style.backgroundColor = "gradient( linear, 0% 0%, 100% 0%, from(#2E2E2D), to( rgba(0, 0, 0, 0.0)) );"
				$.Schedule(0.1,function() {
					lines.ScrollToBottom()
				})
			}
		}

		return true
	}
}

// Called when you receive an Invite
//Checks who invited you, and whether you join him or if its just an Event to refresh
var _OnInviteReceived = function() {

	var numInvites = PartyBrowserAPI.GetInvitesCount()

	for (i = 0; i < numInvites; i++) {
	
		var lobby_xuid = PartyBrowserAPI.GetInviteXuidByIndex(i)
		var xuid = PartyBrowserAPI.GetPartyMemberXuid(lobby_xuid, 0)
		var d = Date.now()
		if(inviteXuids[xuid] >= d -7000) {
			PartyBrowserAPI.ActionJoinParty(lobby_xuid)
			PartyBrowserAPI.ClearInvite(xuid)
			inviteXuids[xuid] = null

			$.Schedule(0.7, function(){
				needsRefresh = 2
			})
		} else {
			invitedByXuids[xuid] = true
			if (gamesenseTabActive){
				needsRefresh = 1
			}

			if (autoJoinToggle && active_category != null && !(PartyListAPI.GetCount() > 1)) {
				PartyBrowserAPI.ActionJoinParty(lobby_xuid)
				autoJoinToggle = false
			}
		}
	}
	
}

// sometimes the lobby is already full and not longer listed serversided
// This shows it for the client which sees its outdated state
var _OnJoinFail = function(xuid, message) {
	inviteXuids[xuid] = null

	if(active_friendlobby_tooltip != null) {
		UiToolkitAPI.ShowTextTooltip(active_friendlobby_tooltip, `<font color='#FF3C3C'>${message}</font>`)
	}
}

// Check if someone leaves/joins the Lobby, if so request a refresh
var _CheckLeaveLobby = function() {
	if(gamesenseTabActive) {
		var in_lobby = LobbyAPI.IsSessionActive() && PartyListAPI.GetCount() > 1

		if(!in_lobby && in_lobby_prev) {
			$.Schedule(0.7, function(){
				needsRefresh = 2
			})
		}
		in_lobby_prev = in_lobby
	}
}

// Returns The Xuid of the Player you are trying to join and/ or if the Script should refresh the listing
var _GetNeedsUpdate = function() {
	var result = {
		refresh: false
	}

	if(joinXuid) {
		result.join_xuid = joinXuid

		var d = Date.now()
		inviteXuids[joinXuid] = d
		joinXuid = null
	}
	if(reserved){
		result.reserved = true
		reserved = null
	}

	if (needsRefresh > 0) {
		result.refresh = needsRefresh
		needsRefresh = 0

		if(needsRefresh == 1){
			_SetLoadProgress(40)
		}
	}

	return result
}

//Sends the Server the Reserved Id when a game has been found
//var _ServerReserved = function(){
//	reserved = true
//}

// Initilizes the Panorama features of the Script
var _Create = function(layout, _tile_layout, _chat_message_layout, _advert_layout, _partymember_layout, _avatar_layout, _herobrine_chat_message_layout) {
	advert_layout = _advert_layout
	tile_layout = _tile_layout
	chat_message_layout = _chat_message_layout
	partymember_layout = _partymember_layout
	avatar_layout = _avatar_layout
	herobrine_chat_message_layout = _herobrine_chat_message_layout

	_Create_Advert()
	_Create_LTP_Tab(layout)

	handler_invitereceived = $.RegisterForUnhandledEvent("PanoramaComponent_PartyBrowser_InviteReceived", _OnInviteReceived)
	handler_playerupdated = $.RegisterForUnhandledEvent("PanoramaComponent_Lobby_PlayerUpdated", _CheckLeaveLobby)
	handler_matchmakingsessionupdate = $.RegisterForUnhandledEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", _CheckLeaveLobby)
	handler_partybrowserrefresh = $.RegisterForUnhandledEvent("PanoramaComponent_PartyBrowser_Refresh", _UpdateNoDataText)
	//handler_serverreserved = $.RegisterForUnhandledEvent("ServerReserved", _ServerReserved)
}

// Used on Unload or GameQuit to reset Panorama
var _Destroy = function() {
	if (panel_lobby_gamesense != null) {
		panel_refresh_gamesense.SetParent(panel_lobby_gamesense)
		panel_lobby_gamesense.RemoveAndDeleteChildren()
		panel_lobby_gamesense.DeleteAsync(0.0)
		panel_lobby_gamesense = null
	}
	
	_RemoveHerobrine()

	panel_refresh_default.visible = true

	for (var key in PartyBrowserAPI_prev) {
		PartyBrowserAPI[key] = PartyBrowserAPI_prev[key]
	}

	for (var key in GameInterfaceAPI_prev) {
		GameInterfaceAPI[key] = GameInterfaceAPI_prev[key]
	}

	if (gamesenseTabActive) {
		gamesenseTabActive = false
		PartyBrowserAPI.Refresh()
		$.DispatchEventAsync(0.0, "PanoramaComponent_PartyBrowser_Refresh")
	}

	if(handler_invitereceived != null) {
		$.UnregisterForUnhandledEvent("PanoramaComponent_PartyBrowser_InviteReceived", handler_invitereceived)
	}
	if(handler_playerupdated != null) {
		$.UnregisterForUnhandledEvent("PanoramaComponent_Lobby_PlayerUpdated", handler_playerupdated)
	}
	if(handler_matchmakingsessionupdate != null) {
		$.UnregisterForUnhandledEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", handler_matchmakingsessionupdate)
	}
	if(handler_partybrowserrefresh != null) {
		$.UnregisterForUnhandledEvent("PanoramaComponent_PartyBrowser_Refresh", handler_partybrowserrefresh)
	}
	//if(handler_serverreserved != null) {
	//	$.UnregisterForUnhandledEvent("ServerReserved", handler_serverreserved)
	//}

	if (panel_advert_gs != null) {
		panel_advert_gs.RemoveAndDeleteChildren()
		panel_advert_gs.DeleteAsync(0.0)
		panel_advert_gs = null
	}

	panel_advert_toggle.GetParent().style.border = null
}

return {
	create: _Create,
	destroy: _Destroy,
	set_players: _SetPP,
	get_needs_update: _GetNeedsUpdate,
	invite: _Invite,
	on_join_fail: _OnJoinFail,
	get_active_category: _GetActiveCategory,
	herobrine_rank_call: _HerobrineRankCall,
	herobrine_summon_try: _HerobrineSummonTry
}
]],"CSGOMainMenu")()

local looking_to_play_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/friendslist.css" />
		<include src="file://{resources}/styles/playercard.css" />
		<include src="file://{resources}/styles/friendtile.css" />
	</styles>
	<Panel class= "horizontal-align-left vertical-center left-right-flow" >
		<RadioButton id="JsFriendsList-lobbies-toolbar-button-gamesense"
			group="JsFriendsList-lobbies-toolbar-button-modegroup"
			class="IconButton friendslist-navbar-lobby-button">
			<Image style="border-radius: 100%; background-color: #272726; width: 26px; height: 26px; padding: -6px -6px;" >
			<Image src="https://raw.githubusercontent.com/Karechta/looking_for_gs/master/gs.png" style="wash-color: #95b806; width: 19px; height: 19px;"/>
			</Image>
		</RadioButton>
		<Button id="JsFriendsList-lobbies-toolbar-button-gamesense-refresh"
					class="IconButton"
					onmouseover="UiToolkitAPI.ShowTextTooltip( 'JsFriendsList-lobbies-toolbar-button-gamesense-refresh', 'Refresh' );"
			onmouseout="UiToolkitAPI.HideTextTooltip();">
			<Image src="file://{images}/icons/ui/refresh.svg"/>
		</Button>
	</Panel>
</root>
]]

local tile_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/friendslist.css" />
		<include src="file://{resources}/styles/playercard.css" />
		<include src="file://{resources}/styles/friendtile.css" />
		<include src="file://{resources}/styles/friendlobby.css" />
	</styles>
	<scripts>
		<include src="file://{resources}/scripts/common/sessionutil.js" />
		<include src="file://{resources}/scripts/friendtile.js" />
		<include src="file://{resources}/scripts/friendlobby.js" />
		<include src="file://{resources}/scripts/friend_advertise_tile.js" />
		<include src="file://{resources}/scripts/common/teamcolor.js" />
		<include src="file://{resources}/scripts/avatar.js" />
	</scripts>
	<Panel>
		<Label id="CategoryText" text="" style="font-size: 16px; text-shadow: 0 0 6px black;"/>
	</Panel>
</root>
]]

local chat_message_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/mainmenu.css" />
		<include src="file://{resources}/styles/chat.css" />
	</styles>
	<Panel>
		<Panel class="chat-entry">
			<Panel id="parent" class="chat-entry__player-invited">
				<Image textureheight="16" texturewidth="-1" src="file://{images}/icons/ui/broadcast.svg"/>
				<Label id="name" style="width: fit-children; padding-right: 0px;" />
				<Label html="true" text="joining via game&lt;font color='#95b806'&gt;sense&lt;/font&gt; lobby browser" acceptsinput="true" style="padding-left: 0px !important;" />
			</Panel>
		</Panel>
	</Panel>
</root>
]]

local advertising_toggle_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/advertising_toggle.css" />
	</styles>
	<Panel class="btn_advertising MainMenuModeOnly">
		<Panel id="HireAdvertisingToggleContainerGS" class="full-width vertical-center" >
			<Button id="HireAdvertisingToggleGS" class="btn_advertising__toggle">
			<Image id="HireAdvertisingToggleGSImage" class="btn_advertising__img-pole" src="https://raw.githubusercontent.com/Karechta/looking_for_gs/master/gs.png" style="width: 56px; height: 56px; border-radius: 50%; padding: 12px 12px;" />
			</Button>
		</Panel>
	</Panel>
</root>

]]

local partymember_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/friendslist.css" />
		<include src="file://{resources}/styles/playercard.css" />
		<include src="file://{resources}/styles/friendtile.css" />
	</styles>
	<Panel class="friendtile friendtile--party" acceptsfocus="true" mousetracking="true">
		<Button id="HerobrineBtn" class="friendtile-contents">
			<Panel class="friendtile__status" >
				<Label id="JsFriendName" class="friendtile__text__title" text="Herobrine"/>
				<Panel class="left-right-flow top-padding" >
					<Image id="HerobrineRank" class="right-padding" textureheight="24" texturewidth="-1" src="file://{images}/icons/skillgroups/skillgroup10.svg"/>
				</Panel>
			</Panel>
		</Button>
	</Panel>
</root>
]]

local avatar_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/avatar.css" />
		<include src="file://{resources}/styles/hud/hudvoicestatus.css" />
	</styles>
	<Button class="avatar avatar--party">
		<Panel class="avatar-image">
			<Panel>
				<Panel class="avatar-image__default"/>
				<CSGOAvatarImage id="HerobrineAvatar" defaultsrc="https://raw.githubusercontent.com/Karechta/looking_for_gs/master/Herobrine_avatar.jpg" class="avatar-image__icon"/>
				<Image id="JsAvatarTeamColor" class="avatar-teamcolor hidden" src="file://{images}/icons/ui/teamcolor.svg" texturewidth="32" textureheight="-1"/>
			</Panel>
		</Panel>
	</Button>
</root>
]]

local herobrine_chat_message_layout = [[
<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/mainmenu.css" />
		<include src="file://{resources}/styles/chat.css" />
	</styles>
	<Panel>
		<Panel class="chat-entry">
			<Panel id="parent" class="chat-entry__player-invited">
				<Image textureheight="16" texturewidth="-1" src="https://raw.githubusercontent.com/Karechta/looking_for_gs/master/Herobrine_avatar.jpg"/>
				<Label html="true" text="  Herobrine joined the game" acceptsinput="true" style="padding-left: 0px !important;" />
			</Panel>
		</Panel>
	</Panel>
</root>
]]


local CRC32_LT = {}
do
	local b, crc, mask
	for i = 1, 256 do
		crc = i - 1
		for _ = 1, 8 do --eight times
			mask = -bit.band(crc, 1)
			crc = bit.bxor(bit.rshift(crc, 1), bit.band(0xedb88320, mask))
		end
		CRC32_LT[i] = crc
	end
end

local function crc32(s)
	-- compute the crc
	local crc = 0xffffffff
	for i = 1, #s do
		local b = string_byte(s, i)
		crc = bit_bxor(bit_rshift(crc, 8), CRC32_LT[bit_band(bit_bxor(crc, b), 0xFF) + 1])
	end
	return bit_band(bit_bnot(crc), 0xffffffff)
end

local function xorstr(key, str)
	local strlen, keylen = #str, #key

	local strbuf = ffi_new("char[?]", strlen+1)
	local keybuf = ffi_new("char[?]", keylen+1)

	ffi_copy(strbuf, str)
	ffi_copy(keybuf, key)

	for i=0, strlen-1 do
		strbuf[i] = bit_bxor(strbuf[i], keybuf[i % keylen])
	end

	return ffi_string(strbuf, strlen)
end

local function vmt_entry(instance, index, type)
	return ffi.cast(type, (ffi.cast("void***", instance)[0])[index])
end

local function vmt_thunk(index, typestring)
	local t = ffi.typeof(typestring)
	return function(instance, ...)
		assert(instance ~= nil)
		if instance then
			return vmt_entry(instance, index, t)(instance, ...)
		end
	end
end

local function vmt_bind(module, interface, index, typestring)
	local instance = client.create_interface(module, interface) or error("invalid interface")
	local fnptr = vmt_entry(instance, index, ffi.typeof(typestring)) or error("invalid vtable")
	return function(...)
		return fnptr(instance, ...)
	end
end

local native_ConnectToGlobalUser = vmt_bind("steamclient.dll", "SteamClient017", 2, "int(__thiscall*)(void*, int)")
local native_GetISteamUser = vmt_bind("steamclient.dll", "SteamClient017", 5, "int*(__thiscall*)(void*, int, int, const char*)")

local native_GetSteamID = vmt_thunk(2, "uint64_t*(__thiscall*)(void*)")

-- get steam pipe and user
local hsteampipe = 1
local hsteamuser = native_ConnectToGlobalUser(hsteampipe)
local isteamuser = native_GetISteamUser(hsteamuser, hsteampipe, "SteamUser017")

local real_steamid3 = tonumber(native_GetSteamID(isteamuser)[0]-76561197960265728ULL)

looking_to_play_js.create(looking_to_play_layout, tile_layout, chat_message_layout, advertising_toggle_layout, partymember_layout, avatar_layout, herobrine_chat_message_layout)

local function api_request(req_type, endpoint, params, callback)
	if req_type == "POST" then
		local body_raw = json_stringify(params)
		local crc = crc32(body_raw)

		local encrypted = xorstr(XOR_KEY, string_format("%s\0%s%d", body_raw, string_reverse(tostring(math_abs(crc))), (crc % 81 + 14) % 9))

		http.request(req_type, BASE_URL .. endpoint, {body = base64_encode(encrypted), user_agent_info = "gamesense_player_finder", headers = {["Content-Type"] = "application/x-www-form-urlencoded"}}, callback)
	else
		http.request(req_type, BASE_URL .. endpoint, {params = params, user_agent_info = "gamesense_player_finder"}, callback)
	end
end

local function set_players(players)
	client.delay_call(0, function()
		looking_to_play_js.set_players(players)
	end)
end

local function log_response_error(text, response)
	client.error_log(text .. " " .. response.status .. " " .. ((response.body ~= nil and response.body:len() < 100) and response.body or (response.status_message or "")))
end

local function refresh_players()
	api_request("GET", "players", {token=remove_token}, function(success, response)
		local data

		if success and response.status == 200 then
			data = json.parse(response.body)
		else
			log_response_error("Failed to refresh players:", response)
			data = {players={}}
		end

		next_refresh = globals.realtime()+1
		set_players(data.players)

		if data.invites and active_category ~= nil then
			for i=1, #data.invites do
				local invite = data.invites[i]
				local result = looking_to_play_js.invite(invite.steamid, true, invite.country)

				if not result then
					for i = 1, 6 do
						client.delay_call(i, function()
							if not result then
								result = looking_to_play_js.invite(invite.steamid, true, invite.country)
							end
						end)
					end
				end
			end
		end
	end)
end

--[[
category: legit semirage rage
localdata:
	steamid: (steamid 64)
	prime: 0, 1
	rank: 0-18
	members: steamid64,steamid64
]]
local function advertise_self(category, localdata)
	local params = {
		steamid = real_steamid3,
		prime = localdata.prime and "1" or "0",
		category = category,
		rank = tostring(localdata.rank)
	}

	if remove_token ~= nil then
		params.token = remove_token
	end

	if localdata.members ~= nil and localdata.members:len() > 0 then
		params.is_leader = localdata.is_leader and "1" or "0"
		params.members = localdata.members
	end

	-- if DEBUG then return end
	api_request("POST", "add", params, function(success, response)
		if not success or response.status ~= 200 then
			return log_response_error("Failed to advertise!", response)
		end

		local data = json.parse(response.body)

		remove_token = data.token
		set_players(data.players)

		next_add = globals.realtime() + ADVERTISE_TIMEOUT
	end)
end

local function remove_self(reason)
	if remove_token ~= nil then
		api_request("POST", "remove", {token = remove_token, reason = reason}, function(success, response)
			if not success or response.status ~= 200 then
				return log_response_error("Failed to remove!", response)
			end
			remove_token = nil

			local data = json.parse(response.body)
			set_players(data.players)
		end)
	end
end

client.set_event_callback("paint_ui", function()
	local realtime = globals.realtime()

	looking_to_play_js.herobrine_rank_call()

	if next_herobrine_tick ~= nil and realtime > next_herobrine_tick then
		looking_to_play_js.herobrine_summon_try()
		next_herobrine_tick = realtime + 1
	end

	active_category = looking_to_play_js.get_active_category()

	if active_category ~= active_category_prev then
		next_add = 0
		active_category_prev = active_category
	end

	local localdata
	if active_category ~= nil or localdata_prev == nil then
		localdata = json.parse(tostring(game_js.get_local_data()))

		if localdata_prev ~= nil then
			-- if anything in localdata changed, send now
			for key, value in pairs(localdata) do
				if localdata_prev[key] ~= value then
					next_add = 0
					break
				end
			end
		end
		localdata_prev = localdata
	end

	if next_add ~= nil and realtime > next_add then
		-- temporarily set this to nil so we dont send a second request while the first request is in progress
		next_add = nil

		if active_category ~= nil then
			advertise_self(active_category, localdata)
		else
			remove_self("active_category")
		end
	end

	if next_refresh ~= nil and realtime > next_refresh then
		local result = json.parse(tostring(looking_to_play_js.get_needs_update()))
		if result.refresh == 1 or (active_category ~= nil and result.refresh == 2) then
			next_refresh = realtime + 10
			refresh_players()
		else
			next_refresh = realtime + 0.05
		end

		if result.join_xuid then
			api_request("POST", "join", {steamid = localdata_prev.steamid, lobby = result.join_xuid}, function(success, response)
				if not success or response.status ~= 200 then
					looking_to_play_js.on_join_fail(result.join_xuid, (response.status == 400 and response.body == "Bad Request: Lobby not found") and "Lobby not found" or "Failed to join lobby: " .. response.status .. " " .. (response.status_message or ""))

					refresh_players()
					return
					--return log_response_error("Failed to join!", response)
				end

				looking_to_play_js.invite(result.join_xuid)
			end)
		end

		-- if result.reserved then
		-- 	local localdata = json.parse(tostring(game_js.get_local_data()))

		-- 	local params = {
		-- 		steamid = localdata.steamid,
		-- 		steamid3 = tostring(real_steamid3),
		-- 		--matchid = SteamNetworkingSockets_SteamNetworkingIdentity_ToString
		-- 	}

		-- 	if localdata.members ~= nil and localdata.members:len() > 0 then
		-- 		params.is_leader = localdata.is_leader and "1" or "0"
		-- 		params.members = localdata.members
		-- 	end

		-- 	api_request("POST", "match", params, function(success, response)
		-- 		if not success or response.status ~= 200 then

		-- 		end
		-- 	end)
		-- end
	end
end)

client.set_event_callback("shutdown", function()
	looking_to_play_js.destroy()

	if remove_token ~= nil then
		remove_self("shutdown")
	end
end)