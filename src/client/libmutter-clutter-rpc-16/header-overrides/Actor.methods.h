/* Extra Actor protos / signature fixes GIR gets wrong for St. */
void clutter_actor_get_abs_allocation_vertices (ClutterActor * self,
                                                graphene_point3d_t verts[4]);
GList * clutter_actor_get_children (ClutterActor * self);
GList * clutter_actor_get_actions (ClutterActor * self);
GList * clutter_actor_get_effects (ClutterActor * self);
GList * clutter_actor_get_constraints (ClutterActor * self);
ClutterActor * clutter_actor_get_stage (ClutterActor * self);
