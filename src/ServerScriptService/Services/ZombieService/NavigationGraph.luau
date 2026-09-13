--!strict

const CollectionService = game:GetService("CollectionService")
const Workspace = game:GetService("Workspace")
const ZombieConfig = require(script.Parent.Config)
const ZombieRaycaster = require(script.Parent.ZombieRaycaster)

const NavigationConfig = ZombieConfig.Navigation
const DebugConfig = ZombieConfig.Debug

type Node = {
	attachment: Attachment,
	connectionAttachments: { Attachment },
}

type FlowField = {
	navigationRevision: number,
	targetAttachment: Attachment,
	nextAttachmentByAttachment: { [Attachment]: Attachment },
}

export type PlayerTarget = {
	player: Player,
	position: Vector3,
	humanoid: Humanoid,
}

type Graph = {
	_nodes: { Node },
	_nodeByAttachment: { [Attachment]: Node },
	_componentIdByAttachment: { [Attachment]: number },
	_flowFieldsByPlayer: { [Player]: FlowField },
	_isDirty: boolean,
	_navigationRevision: number,
	_debugEnabled: boolean,
	_debugFolder: Folder?,
	_raycaster: ZombieRaycaster.Raycaster,
}

const NavigationGraph = {}
NavigationGraph.__index = NavigationGraph

const function hasClearConnection(
	raycaster: ZombieRaycaster.Raycaster,
	fromAttachment: Attachment,
	toAttachment: Attachment
): boolean
	-- Raise the ray slightly above the nodes to avoid hitting their surfaces.
	const origin = fromAttachment.WorldPosition + Vector3.yAxis * NavigationConfig.LinkRayHeight
	const destination = toAttachment.WorldPosition + Vector3.yAxis * NavigationConfig.LinkRayHeight

	return raycaster:Cast(origin, destination - origin) == nil
end

const function findClosestNode(nodes: { Node }, position: Vector3): Node?
	local closestNode: Node? = nil
	local closestDistanceSquared = math.huge

	for _, node in nodes do
		const offset = node.attachment.WorldPosition - position
		-- Use squared distance to avoid computing a square root.
		const distanceSquared = offset:Dot(offset)
		if distanceSquared < closestDistanceSquared then
			closestNode = node
			closestDistanceSquared = distanceSquared
		end
	end

	return closestNode
end

function NavigationGraph.new(raycaster: ZombieRaycaster.Raycaster): Graph
	const self = setmetatable({
		_nodes = {},
		_nodeByAttachment = {},
		_componentIdByAttachment = {},
		_flowFieldsByPlayer = {},
		_isDirty = true,
		_navigationRevision = 0,
		_debugEnabled = false,
		_debugFolder = nil,
		_raycaster = raycaster,
	}, NavigationGraph) :: any

	-- Rebuild the graph when navigation nodes or raycast exclusions change.
	CollectionService:GetInstanceAddedSignal(NavigationConfig.NodeTag):Connect(function()
		self._isDirty = true
	end)

	CollectionService:GetInstanceRemovedSignal(NavigationConfig.NodeTag):Connect(function()
		self._isDirty = true
	end)

	CollectionService:GetInstanceAddedSignal(ZombieRaycaster.IgnoreTag):Connect(function()
		self._isDirty = true
	end)

	CollectionService:GetInstanceRemovedSignal(ZombieRaycaster.IgnoreTag):Connect(function()
		self._isDirty = true
	end)

	return self
end

function NavigationGraph:_clearDebugVisuals()
	if self._debugFolder ~= nil then
		self._debugFolder:Destroy()
		self._debugFolder = nil
	end
end

function NavigationGraph:_rebuildDebugVisuals()
	self:_clearDebugVisuals()

	if self._debugEnabled == false then
		return
	end

	const folder = Instance.new "Folder"
	folder.Name = DebugConfig.NavigationFolderName
	folder.Parent = Workspace

	const nodeIndexByAttachment: { [Attachment]: number } = {}
	for index, node in self._nodes do
		nodeIndexByAttachment[node.attachment] = index

		const marker = Instance.new "Part"
		marker.Name = "Node"
		marker.Shape = Enum.PartType.Ball
		marker.Size = DebugConfig.NodeSize
		marker.Color = DebugConfig.NodeColor
		marker.Material = Enum.Material.Neon
		marker.Transparency = DebugConfig.NodeTransparency
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.Position = node.attachment.WorldPosition
		marker.Parent = folder
	end

	for index, node in self._nodes do
		for _, connectedAttachment in node.connectionAttachments do
			if nodeIndexByAttachment[connectedAttachment] > index then
				const link = Instance.new "Beam"
				link.Name = "Link"
				link.Attachment0 = node.attachment
				link.Attachment1 = connectedAttachment
				link.Color = ColorSequence.new(DebugConfig.LinkColor)
				link.Width0 = DebugConfig.LinkWidth
				link.Width1 = DebugConfig.LinkWidth
				link.FaceCamera = true
				link.LightEmission = 1
				link.Segments = 1
				link.Parent = folder
			end
		end
	end

	self._debugFolder = folder
end

function NavigationGraph:SetDebugEnabled(enabled: boolean)
	self._debugEnabled = enabled
	self._isDirty = true
end

function NavigationGraph:_rebuildIfNeeded()
	if self._isDirty == false then
		return
	end

	const nodes = {}
	const nodeByAttachment = {}

	for _, instance in CollectionService:GetTagged(NavigationConfig.NodeTag) do
		if instance:IsA "Attachment" and instance:IsDescendantOf(Workspace) then
			const node = {
				attachment = instance,
				connectionAttachments = {},
			}
			table.insert(nodes, node)
			nodeByAttachment[instance] = node
		end
	end

	-- Connect nearby nodes that have a clear path between them.
	for index = 1, #nodes do
		const node = nodes[index]
		const nodePosition = node.attachment.WorldPosition

		for otherIndex = index + 1, #nodes do
			const otherNode = nodes[otherIndex]
			const offset = otherNode.attachment.WorldPosition - nodePosition
			if
				offset.Magnitude <= NavigationConfig.LinkDistance
				and math.abs(offset.Y) <= NavigationConfig.MaxVerticalLinkDistance
				and hasClearConnection(self._raycaster, node.attachment, otherNode.attachment)
			then
				table.insert(node.connectionAttachments, otherNode.attachment)
				table.insert(otherNode.connectionAttachments, node.attachment)
			end
		end
	end

	-- Split the graph into isolated connected regions.
	const componentIdByAttachment: { [Attachment]: number } = {}
	local nextComponentId = 0

	for _, node in nodes do
		if componentIdByAttachment[node.attachment] ~= nil then
			continue
		end

		nextComponentId += 1
		componentIdByAttachment[node.attachment] = nextComponentId
		const pendingAttachments = { node.attachment }
		local pendingIndex = 1

		while pendingIndex <= #pendingAttachments do
			const attachment = pendingAttachments[pendingIndex]
			pendingIndex += 1
			const currentNode = nodeByAttachment[attachment]

			for _, connectedAttachment in currentNode.connectionAttachments do
				if componentIdByAttachment[connectedAttachment] == nil then
					componentIdByAttachment[connectedAttachment] = nextComponentId
					table.insert(pendingAttachments, connectedAttachment)
				end
			end
		end
	end

	self._nodes = nodes
	self._nodeByAttachment = nodeByAttachment
	self._componentIdByAttachment = componentIdByAttachment
	table.clear(self._flowFieldsByPlayer)
	self._navigationRevision += 1
	self._isDirty = false
	self:_rebuildDebugVisuals()
end

function NavigationGraph:_buildFlowField(targetNode: Node): FlowField
	const costsByAttachment: { [Attachment]: number } = {}
	const unvisitedAttachments: { [Attachment]: boolean } = {}
	const nextAttachmentByAttachment: { [Attachment]: Attachment } = {}

	for _, node in self._nodes do
		costsByAttachment[node.attachment] = math.huge
		unvisitedAttachments[node.attachment] = true
	end

	costsByAttachment[targetNode.attachment] = 0

	-- Propagate the shortest path cost outward from the target.
	while next(unvisitedAttachments) ~= nil do
		local currentAttachment: Attachment? = nil
		local currentCost = math.huge

		for attachment in unvisitedAttachments do
			const cost = costsByAttachment[attachment]
			if cost < currentCost then
				currentAttachment = attachment
				currentCost = cost
			end
		end

		if currentAttachment == nil or currentCost == math.huge then
			break
		end

		unvisitedAttachments[currentAttachment] = nil
		const currentNode = self._nodeByAttachment[currentAttachment]

		for _, connectedAttachment in currentNode.connectionAttachments do
			if unvisitedAttachments[connectedAttachment] then
				const edgeCost = (
					currentAttachment.WorldPosition - connectedAttachment.WorldPosition
				).Magnitude
				const candidateCost = currentCost + edgeCost

				if candidateCost < costsByAttachment[connectedAttachment] then
					costsByAttachment[connectedAttachment] = candidateCost
					nextAttachmentByAttachment[connectedAttachment] = currentAttachment
				end
			end
		end
	end

	return {
		navigationRevision = self._navigationRevision,
		targetAttachment = targetNode.attachment,
		nextAttachmentByAttachment = nextAttachmentByAttachment,
	}
end

function NavigationGraph:HasNodes(): boolean
	self:_rebuildIfNeeded()
	return #self._nodes > 0
end

function NavigationGraph:FindClosestReachableTarget(
	position: Vector3,
	targets: { PlayerTarget }
): PlayerTarget?
	self:_rebuildIfNeeded()

	const currentNode = findClosestNode(self._nodes, position)
	if currentNode == nil then
		return nil
	end

	const currentComponentId = self._componentIdByAttachment[currentNode.attachment]
	local closestTarget: PlayerTarget? = nil
	local closestDistanceSquared = math.huge

	for _, target in targets do
		-- Ignore targets outside the current connected region.
		const targetNode = findClosestNode(self._nodes, target.position)
		if
			targetNode ~= nil
			and self._componentIdByAttachment[targetNode.attachment] == currentComponentId
		then
			const offset = target.position - position
			const distanceSquared = offset:Dot(offset)
			if distanceSquared < closestDistanceSquared then
				closestTarget = target
				closestDistanceSquared = distanceSquared
			end
		end
	end

	return closestTarget
end

function NavigationGraph:GetSteeringTarget(
	targetPlayer: Player,
	position: Vector3,
	targetPosition: Vector3
): (Vector3?, boolean)
	self:_rebuildIfNeeded()

	const targetNode = findClosestNode(self._nodes, targetPosition)
	const currentNode = findClosestNode(self._nodes, position)
	if targetNode == nil or currentNode == nil then
		return nil, false
	end

	if currentNode.attachment == targetNode.attachment then
		return targetPosition, true
	end

	local flowField = self._flowFieldsByPlayer[targetPlayer]
	-- Rebuild the cached flow field when the graph or target changes.
	if
		flowField == nil
		or flowField.navigationRevision ~= self._navigationRevision
		or flowField.targetAttachment ~= targetNode.attachment
	then
		flowField = self:_buildFlowField(targetNode)
		self._flowFieldsByPlayer[targetPlayer] = flowField
	end

	const nextAttachment = flowField.nextAttachmentByAttachment[currentNode.attachment]
	if nextAttachment == nil then
		return nil, false
	end

	return nextAttachment.WorldPosition, false
end

function NavigationGraph:RemoveTarget(player: Player)
	-- Drop the cached path once the player is no longer a target.
	self._flowFieldsByPlayer[player] = nil
end

return table.freeze(NavigationGraph)
