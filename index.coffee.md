This is a speculative spec for something that uses fleet in order to deploy node applications. It:

* Deploys new jobs to the drone with the least load.
* Restarts jobs when they die
* Optionally monitors jobs/services for health
* Maintains a target number of healthy jobs
* Optionally restarts jobs when they're not healthy
