all:
	gitbook build . docs
	git add .
	git commit -am "build gitbook"
	git push