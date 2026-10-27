/*
 * Clutter.BindConstraint is sealed, so the class vfunc is replaced
 * here. The stock function still writes the box. Placement when
 * get_x or get_y is 0 is gsr_bind_constraint_place in Constraint.vala.
 */

#include <clutter/clutter.h>

static void (*gsr_bind_constraint_stock_update_allocation) (
    ClutterConstraint *constraint,
    ClutterActor      *actor,
    ClutterActorBox   *allocation);

void gsr_bind_constraint_place (ClutterBindConstraint *bind,
                                ClutterActor          *actor,
                                ClutterActorBox       *allocation);

static void
gsr_bind_constraint_update_allocation (ClutterConstraint *constraint,
                                       ClutterActor      *actor,
                                       ClutterActorBox   *allocation)
{
  gsr_bind_constraint_stock_update_allocation (constraint, actor, allocation);
  gsr_bind_constraint_place (CLUTTER_BIND_CONSTRAINT (constraint),
                             actor,
                             allocation);
}

void
gsr_bind_constraint_install (void)
{
  ClutterConstraintClass *klass;

  klass = g_type_class_ref (CLUTTER_TYPE_BIND_CONSTRAINT);
  if (klass->update_allocation == gsr_bind_constraint_update_allocation)
    return;

  gsr_bind_constraint_stock_update_allocation = klass->update_allocation;
  klass->update_allocation = gsr_bind_constraint_update_allocation;
}
