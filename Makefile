all:
	gitbook build . docs
	git add .
	git commit -m"build gitbook"
	git push