function options = pqWitnessDefaults(options)
% pqWitnessDefaults Shape of the ink growth witness band
%
% featureWidth   nominal widths of the ink lines and paper gaps. These are
%                the arm run widths, so that the witness grows the way the
%                arms grow
% pairs          line and gap pairs per feature width, per head. Three, so
%                that the median survives one of them losing a nozzle
% patchColumns   solid reference patch, which gives the ink amplitude every
%                width is measured against
% blockColumns   the solid block a paper gap is cut into. Wide enough that
%                the measuring window around a displaced gap is still inside
%                the ink
% clearColumns   paper between features, wide enough that the window around
%                one feature never reaches the next
if(nargin < 1 || isempty(options))
    options = struct;
end
defaults = struct('featureWidth',[3 7],'rows',120,'clearRows',24, ...
    'pairs',3,'patchColumns',40,'blockColumns',56,'clearColumns',36);
names = fieldnames(defaults);
for k = 1:numel(names)
    if(~isfield(options,names{k}) || isempty(options.(names{k})))
        options.(names{k}) = defaults.(names{k});
    end
end
end
