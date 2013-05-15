This is a speculative spec for something that uses fleet in order to deploy node applications. It:

* Deploys new jobs to the drone with the least load.
* Restarts jobs when they die
* Monitors jobs/services for health
* Restarts jobs when they're not healthy
* Listens for hooks to know a repo has been updated and redeploys it
* Maintains the map of services on Route53
