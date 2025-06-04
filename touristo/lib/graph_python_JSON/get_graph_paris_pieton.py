import osmnx as ox
import networkx as nx
import json
from shapely.geometry import Point

# télécharger le graphe piéton de Paris
print("Téléchargement du graphe piéton de Paris ")
G = ox.graph_from_place("Paris, France", network_type='walk')
G = G.to_undirected()

# de grpahe orienté à graphe non orienté simple
G_undirected = nx.Graph()

for u, v, data in G.edges(data=True):
    length = data.get("length", 1.0)
    if G_undirected.has_edge(u, v):
        if G_undirected[u][v]["length"] > length:
            G_undirected[u][v]["length"] = length
    else:
        G_undirected.add_edge(u, v, length=length)

for n, attr in G.nodes(data=True):
    G_undirected.add_node(n, **attr)
    
G_undirected.graph["crs"] = G.graph["crs"]
# init les données
graph_data = {
    "nodes": [],
    "edges": []
}

# extraire les musées
print("Extraction des musées ")
tags = {"tourism": "museum"}
museums = ox.features_from_place("Paris, France", tags)
museums = museums[museums.geometry.type == "Point"]

# Connecter chaque musée au nœud piéton le plus proche (on créer pas une nouvelle noeuds mais en modifie qui est le plus proche)
print("Connexion des musées au graphe piéton ")
museum_index = 0
for idx, row in museums.iterrows():
    name = row.get("name", "musée inconnu")
    geom = row.geometry
    lat, lon = geom.y, geom.x
    museum_id = f"museum_{museum_index}"
    museum_index += 1

    # trouver le noeud piéton le plus proche
    nearest_node = ox.distance.nearest_nodes(G_undirected, lon, lat)

    # ajouter le musée comme noeud
    graph_data["nodes"].append({
        "id": museum_id,
        "lat": lat,
        "lon": lon,
        "type": "museum",
        "name": name
    })

    # Ajouter une arête entre le musée et le noeud piéton le plus proche
    dist = ox.distance.great_circle(
        lat, lon,
        G_undirected.nodes[nearest_node]['y'],
        G_undirected.nodes[nearest_node]['x']
    )
    graph_data["edges"].append({
        "source": museum_id,
        "target": nearest_node,
        "length": dist
    })

# Ajouter les noeud et arcs du graphe piéton
for node_id, node_data in G_undirected.nodes(data=True):
    graph_data["nodes"].append({
        "id": node_id,
        "lat": node_data["y"],
        "lon": node_data["x"]
    })

for u, v, edge_data in G_undirected.edges(data=True):
    graph_data["edges"].append({
        "source": u,
        "target": v,
        "length": edge_data.get("length", 1.0)
    })

# sauvegarde dans un fichier JSON
output_filename = "paris_walk_graph2.json"
with open(output_filename, "w") as f:
    json.dump(graph_data, f, indent=2)

print(f"Fichier JSON exporté avec succès : {output_filename}")