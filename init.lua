module (..., package.seeall)

local plugin = require 'bamboo.plugin'

local plugin_name = 'pagination'
local path='../plugins/pagination/views/'
local TMPLS = {
	['pagin_a_ajaxpage'] = path .. 'pagin_a_ajaxpage.html',
	['pagin_select_ajax'] = path .. 'pagin_select_ajax.html',	
	['pagin_a'] = path .. 'pagin_a.html',
	['pagin_select'] = path .. 'pagin_select.html',		
}

function helper(_args)
	local params = req.PARAMS
	
	local thepage = tonumber(params.thepage) or 1
	if thepage < 1 then thepage = 1 end
	local totalpages = tonumber(params.totalpages) or 1
	if totalpages and thepage > totalpages then thepage = totalpages end
	local npp = tonumber(params.npp) or tonumber(_args.npp) or 5
	local starti = (thepage-1) * npp + 1
	local endi = thepage * npp
	local paginurl = params.paginurl or _args.paginurl
	local callback = _args.callback
	
	local totalnum, htmlcontent
	local datasource
	if not _args.callback then
		-- assert(_args.content_tmpl)
		-- if supply datasource
		if _args.orig_datasource then
			datasource = List(_args.orig_datasource) or List()
			totalnum = #datasource
			if totalnum then
				totalpages = math.ceil(totalnum/npp)
				if thepage > totalpages	then thepage = totalpages end
			end

			datasource = datasource:slice(starti, endi)
			_args.datasource = datasource
			_args.thepage = thepage
			local content_tmpl = _args.content_tmpl 
			if _args.inline_tmpl then 
				htmlcontent = View(_args.inline_tmpl, 'inline')(_args)
			else
				htmlcontent = View(_args.content_tmpl)(_args)
			end
--			print(totalnum, htmlcontent)
		else
			-- if supply model name, query_args, is_rev
			assert(type(_args.model) == 'string')
			
			local model = bamboo.getModelByName(_args.model)
			assert(model)
			-- if query_args is 'all'
			if not _args.query_args or _args.query_args == 'all' then
				totalnum = model:numbers()
				if _args.is_rev == 'rev' then
					datasource = model:slice(-endi, -starti, 'rev')
				else
					datasource = model:slice(starti, endi)					
				end
			else
				-- if query_args is table or function
				assert(type(_args.query_args) == 'table' or type(_args.query_args) == 'function') 
				if _args.is_rev == 'rev' then
					datasource = model:filter(_args.query_args, -endi, -starti, 'rev')
				else
					datasource = model:filter(_args.query_args, starti, endi)					
				end
				totalnum = model:count(_args.query_args)
			end
			
			_args.datasource = datasource
			_args.thepage = thepage
			if _args.inline_tmpl then 
				htmlcontent = View(_args.inline_tmpl, 'inline')(_args)
			else
				htmlcontent = View(_args.content_tmpl)(_args)
			end
			
		end
	else
		-- if supply callback
		if type(callback) == 'string' then
			local callback_func = bamboo.getPluginCallbackByName(callback)
			assert(type(callback_func) == 'function')
			-- the callback should return 2 values: html fragment and totalnum
			htmlcontent, totalnum = callback_func(starti, endi)
		elseif type(callback) == 'function' then
			htmlcontent, totalnum = callback(starti, endi)
		end
	end
	local prevpage = thepage - 1
	if prevpage < 1 then prevpage = 1 end
	local nextpage = thepage + 1
	if nextpage > totalpages then nextpage = totalpages end
	
	return {
		['_tag'] = _args._tag,
		['totalnum'] = totalnum,
		['htmlcontent'] = htmlcontent, 
		['totalpages'] = totalpages, 
		['npp'] = npp, 
		['paginurl'] = paginurl, 
		['thepage'] = thepage, 
		['prevpage'] = prevpage, 
		['nextpage'] = nextpage
	}
end

function page(web, req)
	local params = req.PARAMS
	assert(params._tag, '[Error] @plugin pagination function page - missing _tag.')
	local _args = plugin.unpersist(plugin_name, params._tag)
	
	return web:page(View(TMPLS[_args.tmpl])(helper(_args)))
end

function json(web, req)
	local params = req.PARAMS
	assert(params._tag, '[Error] @plugin pagination function json - missing _tag.')
	local _args = plugin.unpersist(plugin_name, params._tag)

	return web:jsonSuccess(helper(_args))
end


--[[

{^ pagination 
datasource=all_persons,
inline_tmpl = inline_variable,
content_tmpl="item.html", 
npp=20,
pagintype = 'json',
^}

--]]
function main(args, env)
	assert(args._tag, '[Error] @plugin pagination - missing _tag.')
	--assert(args.paginurl, '[Error] @plugin pagination - missing paginurl.')

	local purl = '/pagination/'..args._tag..'/page/'
	local jurl = '/pagination/'..args._tag..'/json/'
	local urls = {
		[purl] = page,
		[jurl] = json,
	}
	table.update(bamboo.URLS, urls)
	
	if args.datasource then
		args.orig_datasource = args.datasource
	end
	
	-- default choose pagin_a style
	args.tmpl = args.tmpl or 'pagin_select_ajax'
	args.paginurl = args.tmpl:endsWith('_ajax') and jurl or purl

	plugin.persist(plugin_name, args)

	return View(TMPLS[args.tmpl]) (helper(args))
end

