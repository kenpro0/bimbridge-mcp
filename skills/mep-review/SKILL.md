---
name: mep-review
description: Read-only MEP model review in Revit. Content summary, open connectors, ducts and pipes outside systems, system list, uninsulated runs, flat gravity pipes, electrical devices without circuit. Use before coordination meetings.
---

# MEP model review

Read `revit-scripting` first. Every check below is a `run_query`: it reads the model and changes nothing.

Run the checks the user asks for, or the full review in this order. Then give one summary table (check, count, where, next step) and offer to select the problem elements with `show_elements`.

Before you start, ask the user two things if they matter for the checks they want: which systems must be insulated, and the minimum slope for gravity drainage. Use 1 % if they don't know.

Each script returns counts plus at most 200 element ids per list. On a large model, run one check at a time and raise `timeout_s`. Models differ between templates and Revit versions: when a call fails, check the member with `lookup_revit_api` and adapt the script.

## 1. MEP content summary

```python
from pyrevit.api import DB

CATEGORIES = [
    ("Ducts", DB.BuiltInCategory.OST_DuctCurves),
    ("Flex ducts", DB.BuiltInCategory.OST_FlexDuctCurves),
    ("Duct fittings", DB.BuiltInCategory.OST_DuctFitting),
    ("Duct accessories", DB.BuiltInCategory.OST_DuctAccessory),
    ("Air terminals", DB.BuiltInCategory.OST_DuctTerminal),
    ("Mechanical equipment", DB.BuiltInCategory.OST_MechanicalEquipment),
    ("Pipes", DB.BuiltInCategory.OST_PipeCurves),
    ("Flex pipes", DB.BuiltInCategory.OST_FlexPipeCurves),
    ("Pipe fittings", DB.BuiltInCategory.OST_PipeFitting),
    ("Pipe accessories", DB.BuiltInCategory.OST_PipeAccessory),
    ("Plumbing fixtures", DB.BuiltInCategory.OST_PlumbingFixtures),
    ("Sprinklers", DB.BuiltInCategory.OST_Sprinklers),
    ("Cable trays", DB.BuiltInCategory.OST_CableTray),
    ("Conduits", DB.BuiltInCategory.OST_Conduit),
    ("Electrical equipment", DB.BuiltInCategory.OST_ElectricalEquipment),
    ("Electrical fixtures", DB.BuiltInCategory.OST_ElectricalFixtures),
    ("Lighting fixtures", DB.BuiltInCategory.OST_LightingFixtures),
]

def count(category):
    collector = DB.FilteredElementCollector(doc).OfCategory(category)
    return collector.WhereElementIsNotElementType().GetElementCount()

result = [{"category": name, "count": count(category)} for name, category in CATEGORIES]
```

## 2. Open connectors

Physical connector ends that are not connected, for HVAC and piping. Electrical connectors are logical: section 7 checks them.

```python
from pyrevit.api import DB

CATEGORIES = [
    DB.BuiltInCategory.OST_DuctCurves, DB.BuiltInCategory.OST_FlexDuctCurves,
    DB.BuiltInCategory.OST_DuctFitting, DB.BuiltInCategory.OST_DuctAccessory,
    DB.BuiltInCategory.OST_DuctTerminal, DB.BuiltInCategory.OST_MechanicalEquipment,
    DB.BuiltInCategory.OST_PipeCurves, DB.BuiltInCategory.OST_FlexPipeCurves,
    DB.BuiltInCategory.OST_PipeFitting, DB.BuiltInCategory.OST_PipeAccessory,
    DB.BuiltInCategory.OST_PlumbingFixtures, DB.BuiltInCategory.OST_Sprinklers,
]

def connectors(element):
    manager = getattr(element, "ConnectorManager", None)  # ducts and pipes
    if manager is None:
        model = getattr(element, "MEPModel", None)  # fittings, equipment, terminals
        manager = model.ConnectorManager if model is not None else None
    return list(manager.Connectors) if manager is not None else []

def level_name(element):
    level = getattr(element, "ReferenceLevel", None)  # ducts and pipes
    if level is None and element.LevelId != DB.ElementId.InvalidElementId:
        level = doc.GetElement(element.LevelId)
    return level.Name if level is not None else "(no level)"

found = []
by_level = {}
for category in CATEGORIES:
    collector = DB.FilteredElementCollector(doc).OfCategory(category).WhereElementIsNotElementType()
    for element in collector:
        try:
            open_ends = [c for c in connectors(element)
                         if c.ConnectorType == DB.ConnectorType.End
                         and c.Domain != DB.Domain.DomainElectrical
                         and not c.IsConnected]
            if not open_ends:
                continue
            level = level_name(element)
            by_level[level] = by_level.get(level, 0) + 1
            if len(found) < 200:
                point = open_ends[0].Origin
                found.append({
                    "id": element.Id,
                    "category": element.Category.Name,
                    "level": level,
                    "open_ends": len(open_ends),
                    "point_m": [round(point.X * 0.3048, 2), round(point.Y * 0.3048, 2), round(point.Z * 0.3048, 2)],
                })
        except Exception:
            continue

result = {"elements_with_open_ends": sum(by_level.values()), "by_level": by_level, "first_200": found}
```

Open ends on equipment are often normal while a model is in progress. Say so in the summary.

## 3. Ducts and pipes outside any system

```python
from pyrevit.api import DB

CATEGORIES = [
    ("Ducts", DB.BuiltInCategory.OST_DuctCurves),
    ("Flex ducts", DB.BuiltInCategory.OST_FlexDuctCurves),
    ("Pipes", DB.BuiltInCategory.OST_PipeCurves),
    ("Flex pipes", DB.BuiltInCategory.OST_FlexPipeCurves),
]

result = {}
for name, category in CATEGORIES:
    total = 0
    ids = []
    collector = DB.FilteredElementCollector(doc).OfCategory(category).WhereElementIsNotElementType()
    for element in collector:
        try:
            if element.MEPSystem is not None:
                continue
        except Exception:
            continue
        total += 1
        if len(ids) < 200:
            ids.append(element.Id)
    result[name] = {"count": total, "ids": ids}
```

## 4. System list

```python
from pyrevit.api import DB
from Autodesk.Revit.DB import Mechanical, Plumbing

rows = []
for system_class, kind in ((Mechanical.MechanicalSystem, "HVAC"), (Plumbing.PipingSystem, "Piping")):
    for system in DB.FilteredElementCollector(doc).OfClass(system_class):
        try:
            classification = system.get_Parameter(DB.BuiltInParameter.RBS_SYSTEM_CLASSIFICATION_PARAM)
            equipment = system.BaseEquipment
            rows.append({
                "kind": kind,
                "name": system.Name,
                "classification": classification.AsString() if classification is not None else None,
                "element_count": system.Elements.Size,
                "base_equipment": equipment.Name if equipment is not None else None,
            })
        except Exception:
            continue

rows.sort(key=lambda row: (row["kind"], row["name"]))
result = {
    "count": len(rows),
    "without_base_equipment": len([row for row in rows if row["base_equipment"] is None]),
    "systems": rows[:300],
}
```

## 5. Uninsulated ducts and pipes

Grouped by system type, so the user can say which groups really need insulation.

```python
from pyrevit.api import DB

CATEGORIES = [
    ("Ducts", DB.BuiltInCategory.OST_DuctCurves, DB.BuiltInParameter.RBS_DUCT_SYSTEM_TYPE_PARAM),
    ("Pipes", DB.BuiltInCategory.OST_PipeCurves, DB.BuiltInParameter.RBS_PIPING_SYSTEM_TYPE_PARAM),
]

result = {}
for name, category, system_type_parameter in CATEGORIES:
    groups = {}
    collector = DB.FilteredElementCollector(doc).OfCategory(category).WhereElementIsNotElementType()
    for element in collector:
        try:
            if DB.InsulationLiningBase.GetInsulationIds(doc, element.Id).Count > 0:
                continue
            parameter = element.get_Parameter(system_type_parameter)
            system_type = parameter.AsValueString() if parameter is not None else None
        except Exception:
            continue
        group = groups.setdefault(system_type or "(no system type)", {"count": 0, "ids": []})
        group["count"] += 1
        if len(group["ids"]) < 50:
            group["ids"].append(element.Id)
    result[name] = groups
```

## 6. Gravity drainage pipes below the minimum slope

```python
from pyrevit.api import DB
from Autodesk.Revit.DB import Plumbing

MIN_SLOPE = 0.01  # 1 %; use the value the user gives

total = 0
pipes = []
for pipe in DB.FilteredElementCollector(doc).OfClass(Plumbing.Pipe):
    try:
        system = pipe.MEPSystem
        if system is None or system.SystemType != Plumbing.PipeSystemType.Sanitary:
            continue
        slope = pipe.get_Parameter(DB.BuiltInParameter.RBS_PIPE_SLOPE).AsDouble()
    except Exception:
        continue
    if slope < MIN_SLOPE:
        total += 1
        if len(pipes) < 200:
            pipes.append({"id": pipe.Id, "system": system.Name, "slope_percent": round(slope * 100, 2)})

result = {"min_slope_percent": MIN_SLOPE * 100, "pipes_below_min": total, "first_200": pipes}
```

Vertical stacks have no slope: ignore pipes that are vertical if the user asks you to refine this check.

## 7. Electrical devices without a circuit

Devices that have an electrical connector but belong to no circuit.

```python
from pyrevit.api import DB

CATEGORIES = [
    DB.BuiltInCategory.OST_ElectricalFixtures,
    DB.BuiltInCategory.OST_LightingFixtures,
    DB.BuiltInCategory.OST_LightingDevices,
    DB.BuiltInCategory.OST_FireAlarmDevices,
    DB.BuiltInCategory.OST_DataDevices,
    DB.BuiltInCategory.OST_CommunicationDevices,
]

def has_electrical_connector(element):
    model = getattr(element, "MEPModel", None)
    manager = model.ConnectorManager if model is not None else None
    if manager is None:
        return False
    return any(c.Domain == DB.Domain.DomainElectrical for c in manager.Connectors)

total = 0
devices = []
for category in CATEGORIES:
    collector = DB.FilteredElementCollector(doc).OfCategory(category).WhereElementIsNotElementType()
    for element in collector:
        try:
            if not has_electrical_connector(element):
                continue
            if element.MEPModel.GetElectricalSystems().Count > 0:
                continue
            family = element.Symbol.FamilyName
        except Exception:
            continue
        total += 1
        if len(devices) < 200:
            devices.append({"id": element.Id, "category": element.Category.Name, "family": family, "type": element.Name})

result = {"devices_without_circuit": total, "first_200": devices}
```

## Present the results

- One table: check, count, where (the levels or systems with the most issues), next step.
- Offer to select or isolate one group with `show_elements` (ids, zoom).
- Fixing or tagging problems is a model change: it goes through `run_modify` and the user's approval in Revit.
- Give sizes in millimeters and slopes in percent.
