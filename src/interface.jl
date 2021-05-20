module TypecheckMain
end

function add_file_root(path)
	includet(TypecheckMain, path) # evaluate the file in the typecheck main environment
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