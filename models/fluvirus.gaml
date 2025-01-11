/**
* Name: fluvirus
* Based on the internal empty template. 
* Author: ryuiji
* Tags: 
*/


model fluvirus


global {
	shape_file shapefile_buildings <- shape_file("../includes/buildings.shp");
	shape_file shapefile_roads <- shape_file("../includes/roads.shp");

	geometry shape <- envelope(shapefile_roads,shapefile_buildings);
	graph road_network;
	building biggest_building;
	float step <- 5#mn;
	
	float vaccination_rate <- 0.005;
	int nb_init_people <- 3000;
	int number_infected_init <- 10;
	float infection_probability <- 0.33;
	float mutation_probability <- 0.0005;
	float infection_distance <- 1.0#m;
	float recovery_probability <- 0.1;
	float testing_percentage <- 0.1;

	
	init {
		create virus number: 1 {
			inf_prob <- infection_probability;
		}
		create authorities number: 1;
		create building from: shapefile_buildings;
		biggest_building <- building with_max_of each.shape.area;
		ask biggest_building {
			is_school <- true;
		}
		create road from: shapefile_roads;
		create people number: nb_init_people;
		ask 70 among building {
			is_workplace <- true;
		}
		loop ag over: building where (!each.is_workplace and !each.is_school) {
			int nb_people_family <- rnd(3,6);
			int nb_kids_family <- rnd(0,2);
			ask (nb_people_family - nb_kids_family) among (people where (each.house = nil)) {
				house  <- ag;
				workplace <- one_of(building where (each.is_workplace));
				location <- any_location_in(house);
			}
			ask nb_kids_family among (people where (each.house = nil)) {
				is_child <- true;
				house  <- ag;
				school <- one_of(biggest_building);
				location <- any_location_in(house);
			}
		}
		
		ask number_infected_init among people {
			is_infected <- true;
			VIRUS <- one_of(virus);
			all_virus_contracted << VIRUS;
		}
		
		road_network <- as_edge_graph(road);
		
	}
	
	reflex end_simulation when: people count (!each.is_infected) = nb_init_people {
		write("End of simulation");
		do pause;
    }
}

species virus {
	float inf_prob;
}

species building {
	bool is_school <- false;
	bool is_workplace <- false;
	
	aspect default {
		draw shape color: #darkgray;
	}
}


species road {	
	aspect default {
		draw shape color: #yellow;
	}
}

species people skills: [moving] {
	point target;
	building house;
	building workplace;
	building school;
	bool is_child;
	virus VIRUS;
	list<virus> all_virus_contracted;
	virus VACIN;
	list<virus> all_vaccine;
	
	int recovery_time <- 0;
	int isolated_time <- 0;
	bool is_infected <- false;
	bool is_vaccinated <- false;
	bool is_isolated <- false;
	
	
	float infect_prob <- infection_probability;
	rgb color -> is_infected ? #red : #green;
	list<people> neighbours -> people at_distance infection_distance;
	
	reflex infection_prob when: (VIRUS != nil) {
		infect_prob <- VIRUS.inf_prob;
		if (is_vaccinated) {
			infect_prob <- infect_prob/3;
			if (all_vaccine contains VIRUS) {
				
			} else {
				infect_prob <- infect_prob * 2;
			}
		}
	}
	
	reflex isolation when: (world.time mod 86400 = 25200 and is_isolated) {
   		if (isolated_time = 12) {
   			is_isolated <- false;
   			isolated_time <- 0;
   		}
   		isolated_time <- isolated_time + 1;
   	}
	
	reflex gowork when: (world.time mod 86400 = 32400 and !is_isolated) {
		if (is_child) {
			target <- any_location_in(school);
		}
		else {
			target <- any_location_in(workplace);
		}
   		
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
   	
   	reflex recover when: (world.time mod 86400 = 25200 and is_infected) {
   		if (recovery_time = 10 or flip(recovery_probability)) {
   			is_infected <- false;
   			recovery_time <- 0;
   			VIRUS <- nil;
   		} else {
   			recovery_time <- recovery_time + 1;
   		}
   	}	
   	
   	reflex move when: target != nil {
		do goto target: target on: road_network;
		if(location = target) {
			target <- nil;
		}
	}
	
	reflex mutation when: (world.time mod 86400 = 25200 and flip(mutation_probability) and is_infected){
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

species authorities {
	map<virus,int> list_virus;
	int max_value <- 0;
	virus VACCIN_URGENCE;
	
	reflex vaccination when: world.time mod 86400 = 25200 {
		ask int(vaccination_rate * nb_init_people) among (people where(not(each.all_vaccine contains VACCIN_URGENCE))) {
			is_vaccinated <- true;
			VACIN <- myself.VACCIN_URGENCE;
			all_vaccine << myself.VACCIN_URGENCE;
		}
	}
	
	reflex testing when: world.time mod 86400 = 25200 {
		ask int(testing_percentage * nb_init_people) among (people where(!each.is_isolated)) {
			if (is_infected) {
				is_isolated <- true;
			}
		}
	}
	
	reflex counting when: world.time mod 86400 = 25200 {
		loop ag over: virus {
			list_virus[ag] <- people count (each.VIRUS = ag);
			if (list_virus[ag] > max_value) {
				max_value <- list_virus[ag];
				VACCIN_URGENCE <- ag;
			}
		}
		write(list_virus);
		max_value <- 0;
	}
}



experiment test {
	parameter "Nb people" var: nb_init_people step:100 max: 3100;
	parameter "Vaccination rate" var: vaccination_rate min:0 max: 1.0;
	parameter "Infection distance" var: infection_distance;	
	parameter "Probaibilty of infection" var: infection_probability min:0 max: 1.0;
	parameter "Probaibilty of virus mutation" var: mutation_probability min:0 max: 1.0;
	parameter "Distance of infection" var: infection_distance ;
	parameter "Probaibilty of recovery" var: recovery_probability min:0 max: 1.0;
	parameter "Testing rate" var: testing_percentage min:0 max: 1.0;

	
	
	
	output {
		monitor nb_infected value: people count (each.is_infected) refresh: every(1#cycle) color: #blue;
		monitor vaccinated_ratio value: people count (each.is_vaccinated)/nb_init_people refresh: every(1#cycle) color: #blue;
		monitor nb_isolated value: people count (each.is_isolated) refresh: every(1#cycle) color: #blue;
		
		monitor nb_virus value: authorities(0).VACCIN_URGENCE refresh: every(1#cycle) color: #blue;
		
		display fluvirus {
			species building;
			species road;
			species people;
			species authorities;
			species virus;
		}
		display chart {
			chart "people infected over the time" type: series {
				data "nb of infected people" value: people count (each.is_infected) color: #red;
				data "nb of isolated people " value: people count (each.is_isolated) color: #green;
				data "nb of vaccinated people " value: people count (each.is_vaccinated) color: #blue;
				
			}
		}
	}
}