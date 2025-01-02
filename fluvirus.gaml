/**
* Name: fluvirus
* Based on the internal empty template. 
* Author: ryuiji
* Tags: 
*/


model fluvirus


global {
	file shapefile_buildings <- file("../includes/buildings.shp");
	file shapefile_roads <- file("../includes/roads.shp");
	geometry shape <- envelope(shapefile_roads);
	graph road_network;
	float step <- 1#mn;
	
	
	float vaccination_rate <- 0.05;
	int nb_init_people <- 5000;
	int number_infected_init <- 10;
	float infection_probability <- 0.33;
	float mutation_probability <- 0.01;
	float infection_distance <- 1.0#m;
	float recovery_probability <- 0.1;
	float testing_percentage <- 0.1;

	
	init {
		create virus number: 1 {
			inf_prob <- infection_probability;
		}
		create authorities number: 1;
		create building from: shapefile_buildings;
		create road from: shapefile_roads;
		create people number: nb_init_people {
			house <- one_of(building);
			workplace <- one_of(building);
			location <- any_location_in(house);
		}
		
		ask number_infected_init among people {
			is_infected <- true;
			VIRUS <- one_of(virus);
			all_virus_contracted << VIRUS;
		}
		
		road_network <- as_edge_graph(road);
		
	}
	
	
}

species virus {
	float inf_prob;
}

species building {
	aspect default {
		draw shape color: #darkgray;
	}
}


species road {
	float capacity <- 1 + shape.perimeter/30;
	int nb_drivers <- 0 update: length(people at_distance 1);
	float speed_rate <- 1.0 update: exp(-nb_drivers/capacity) min: 0.1;
	
	aspect default {
		draw shape color: #yellow;
	}
}

species people skills: [moving] {
	point target;
	building house;
	building workplace;
	virus VIRUS;
	list<virus> all_virus_contracted;
	
	int recovery_time <- 0;
	int isolated_time <- 0;
	bool is_infected <- false;
	bool is_vaccinated <- false;
	bool is_isolated <- false;
	
	float personal_infection_probability -> (VIRUS != nil) ? VIRUS.inf_prob : infection_probability;
	float infect_prob -> is_vaccinated ? personal_infection_probability/3 : personal_infection_probability;
	rgb color -> is_infected ? #red : #green;
	list<people> neighbours -> people at_distance infection_distance;
	
	
	reflex gowork when: (world.time mod 86400 = 32400 and !is_isolated) {
   		target <- any_location_in(workplace);
	}
	
	reflex gohome when: (world.time mod 86400 = 61200 and !is_isolated) {
   		target <- any_location_in(house);
	}
	
	reflex become_infected when: (is_infected and flip(infect_prob)){
      ask neighbours {
      		if (all_virus_contracted contains myself.VIRUS) {
      			
      		} else {
      			all_virus_contracted << myself.VIRUS;
      			is_infected <- true;
      			VIRUS <- myself.VIRUS;
      		}
    	}
   	}
   	
   	reflex recover when: (world.time mod 86400 = 43200 and is_infected) {
   		if (recovery_time = 10 or flip(recovery_probability)) {
   			is_infected <- false;
   			recovery_time <- 0;
   		} else {
   			recovery_time <- recovery_time + 1;
   		}
   	}
   	
   	reflex isolation when: (world.time mod 86400 = 43200 and is_isolated) {
   		isolated_time <- isolated_time + 1;
   	}
   	
   	reflex move when: target != nil {
		do goto target: target on: road_network;
		if(location = target) {
			target <- nil;
		}
	}
	
	reflex mutation when: (world.time mod 86400 = 43200 and flip(mutation_probability) and is_infected){
		create virus number: 1{
			inf_prob <- infection_probability * rnd(0.5,1.5);
		}
		VIRUS <- last(virus);
		all_virus_contracted << VIRUS;
	}
   	
	aspect default {
		draw circle(10) color: color;
	}
}


species children parent: people {
	building school;
}


species authorities {
	reflex vaccination when: world.time mod 86400 = 43200 {
		ask int(vaccination_rate * nb_init_people) among (people where(!each.is_vaccinated)) {
			is_vaccinated <- true;
		}
	}
	
	reflex testing when: world.time mod 86400 = 43200 {
		
	}
}



experiment test {
	output {
		monitor nb_infected value: people count (each.is_infected) refresh: every(1#cycle) color: #blue;
		monitor nb_vaccinated value: people count (each.is_vaccinated) refresh: every(1#cycle) color: #blue;
		//monitor nb_virus value: virus count (each) refresh: every(1#cycle) color: #blue;
		
		
		display fluvirus {
			species building;
			species road;
			species people;
			species authorities;
			species virus;
		}
	}
}