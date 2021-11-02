module TypecheckMain
end

function add_file_root(path)
	@info "evaluating $path for typechecking"
	# hacky thingie to figure out if the path is to a test or not
	if "test" in Base.Filesystem.splitpath(path)
		@info "skipping $path as it seems to be a test file"
		return
	end
	TypecheckMain.include(path)# evaluate the file in the typecheck main environment
	id = Base.PkgId(Main)
	pkgdata = Revise.parse_pkg_files(id) # grab the includes off of the stack and add them to Revise
	Revise.init_watching(pkgdata)
	Revise.pkgdatas[id] = pkgdata
end

function typecheck_cst(expr::CSTParser.EXPR)
	typecheck_toplevel(expr)
end

#=
function typecheck_file(path, file, cst)
	# we first need to check that revise knows about the file/it's available from the package root
	if !(dirname(file) in Revise.watched_files) || !(basename(file) in Revise.watched_files[dirname(file)])
		# if it doesn't, then we can't typecheck it (no context available)
		# return without typechecking
		return
	end
	#revise knows about the file. Get the pkgid attached to it.
	pkg_id = Revise.watched_files[dirname(file)])[basename(file)]

end
=#
